import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "sequence", "submitter", "resetter", "mortgageFields", "mortgageNote", "manualMunicipality", "propertyVat"]
  static values = {
    draftEnabled: { type: Boolean, default: false },
    draftKey: String,
    resetUrl: String
  }

  connect() {
    this.timer = null
    this.draftTimer = null
    this.restoreFrame = null
    this.draftDirty = false
    this.restoringDraft = false
    this.handlePageHide = () => this.saveDraft()
    window.addEventListener("pagehide", this.handlePageHide)

    if (this.draftEnabledValue && this.hasDraftKeyValue) {
      this.restoreFrame = window.requestAnimationFrame(() => this.restoreDraft())
    }
  }

  disconnect() {
    window.clearTimeout(this.timer)
    window.clearTimeout(this.draftTimer)
    window.cancelAnimationFrame(this.restoreFrame)
    window.removeEventListener("pagehide", this.handlePageHide)
    this.saveDraft()
  }

  queue(event) {
    if (this.restoringDraft || event.target.closest(".scenario-rename") || event.target.dataset.skipRecalculation === "true") return

    this.markDraftChanged()
    window.clearTimeout(this.timer)
    this.timer = window.setTimeout(() => this.recalculate(), 420)
  }

  rememberInput(event) {
    if (this.restoringDraft || event.target.closest(".scenario-rename") || event.target.dataset.skipRecalculation === "true") return

    this.markDraftChanged()
  }

  rememberInterfaceState(event) {
    if (!event.target.closest("summary, [data-calculator-tabs-target='tab'], [data-action~='schedule-editor#add']")) return

    this.markDraftChanged()
  }

  recalculate() {
    if (!this.hasFormTarget || !this.hasSubmitterTarget) return

    this.sequenceTarget.value = Number(this.sequenceTarget.value || 0) + 1
    this.submitterTarget.click()
  }

  guard(event) {
    if (!this.hasSequenceTarget || event.target.id !== "calculator-results" && event.target.id !== "mortgage-results") return

    const incoming = Number(event.detail.newFrame?.dataset.sequence || 0)
    const current = Number(this.sequenceTarget.value || 0)
    if (incoming < current) event.preventDefault()
  }

  toggleFinancing(event) {
    const hidden = event.target.value !== "mortgage"

    if (this.hasMortgageFieldsTarget) this.mortgageFieldsTarget.hidden = hidden
    if (this.hasMortgageNoteTarget) this.mortgageNoteTarget.hidden = hidden
  }

  toggleMunicipality(event) {
    if (this.hasManualMunicipalityTarget) this.manualMunicipalityTarget.hidden = event.target.value !== "other"
  }

  togglePropertyVat(event) {
    if (this.hasPropertyVatTarget) this.propertyVatTarget.hidden = event.target.value !== "net"
  }

  reset() {
    if (!window.confirm("Да започнем ли нова празна сметка? Текущите незапазени данни ще бъдат изчистени. Запазените сметки няма да бъдат изтрити.")) return

    this.draftEnabledValue = false
    this.draftDirty = false
    window.clearTimeout(this.draftTimer)

    try {
      window.sessionStorage.removeItem(this.draftStorageKey)
    } catch (_error) {
      // Continue to the blank calculator when storage is unavailable.
    }

    if (this.hasResetUrlValue) window.location.assign(this.resetUrlValue)
  }

  markDraftChanged() {
    this.showResetter()
    if (!this.draftEnabledValue || !this.hasDraftKeyValue || this.restoringDraft) return

    this.draftDirty = true
    window.clearTimeout(this.draftTimer)
    this.draftTimer = window.setTimeout(() => this.saveDraft(), 140)
  }

  saveDraft() {
    if (!this.draftEnabledValue || !this.hasDraftKeyValue || !this.hasFormTarget || !this.draftDirty || this.restoringDraft) return

    const payload = {
      version: 1,
      savedAt: new Date().toISOString(),
      controls: this.serializedControls(),
      scheduleRows: this.serializedScheduleRows(),
      openDetails: Array.from(this.formTarget.querySelectorAll("details")).map((details) => details.open),
      activeSection: this.element.querySelector("[data-calculator-tabs-target='tab'][aria-selected='true']")?.dataset.section || null
    }

    try {
      window.sessionStorage.setItem(this.draftStorageKey, JSON.stringify(payload))
      this.draftDirty = false
    } catch (_error) {
      // Storage can be unavailable in privacy-restricted browser contexts.
    }
  }

  restoreDraft() {
    let payload

    try {
      payload = JSON.parse(window.sessionStorage.getItem(this.draftStorageKey))
    } catch (_error) {
      return
    }

    if (payload?.version !== 1 || !Array.isArray(payload.controls)) return

    this.showResetter()
    this.restoringDraft = true
    try {
      const scheduleController = this.application.getControllerForElementAndIdentifier(this.element, "schedule-editor")
      if (scheduleController && Array.isArray(payload.scheduleRows)) scheduleController.restoreRows(payload.scheduleRows)

      const restoredControls = this.restoreControls(payload.controls)
      this.restoreDetails(payload.openDetails)
      this.restoreSection(payload.activeSection)
      scheduleController?.syncEventSelectors()
      this.dispatchRestoredControls(restoredControls)
      this.recalculate()
    } finally {
      this.restoringDraft = false
    }
  }

  serializedControls() {
    return Array.from(this.formTarget.elements)
      .filter((control) => control.name?.startsWith("calculator[") && control.type !== "hidden" && !["submit", "button"].includes(control.type))
      .map((control) => ({
        name: control.name,
        type: control.type,
        value: control.value,
        ...(["checkbox", "radio"].includes(control.type) ? { checked: control.checked } : {})
      }))
  }

  serializedScheduleRows() {
    return Array.from(this.formTarget.querySelectorAll("[data-schedule-editor-target~='row']")).map((row) => ({
      values: Object.fromEntries(Array.from(row.querySelectorAll("[data-field]")).map((control) => [control.dataset.field, control.value])),
      advancedOpen: Boolean(row.querySelector(".schedule-row__advanced")?.open)
    }))
  }

  restoreControls(items) {
    const controls = Array.from(this.formTarget.elements)
    const restored = []

    items.forEach((item) => {
      const matches = controls.filter((control) => control.name === item.name && control.type === item.type)
      const control = ["checkbox", "radio"].includes(item.type)
        ? matches.find((candidate) => candidate.value === item.value)
        : matches[0]
      if (!control) return

      if (["checkbox", "radio"].includes(item.type)) control.checked = Boolean(item.checked)
      else control.value = item.value

      if (item.type !== "radio" || control.checked) restored.push(control)
    })

    return restored
  }

  restoreDetails(states) {
    if (!Array.isArray(states)) return

    this.formTarget.querySelectorAll("details").forEach((details, index) => {
      if (typeof states[index] === "boolean") details.open = states[index]
    })
  }

  restoreSection(section) {
    if (!section) return

    const tabs = Array.from(this.element.querySelectorAll("[data-calculator-tabs-target='tab']"))
    if (!tabs.some((tab) => tab.dataset.section === section)) return

    tabs.forEach((tab) => tab.setAttribute("aria-selected", String(tab.dataset.section === section)))
    this.element.querySelectorAll("[data-calculator-tabs-target='panel']").forEach((panel) => {
      panel.hidden = panel.dataset.section !== section
    })
  }

  dispatchRestoredControls(controls) {
    Array.from(new Set(controls)).forEach((control) => {
      control.dispatchEvent(new Event("input", { bubbles: true }))
      control.dispatchEvent(new Event("change", { bubbles: true }))
    })
  }

  showResetter() {
    if (this.hasResetterTarget) this.resetterTarget.hidden = false
  }

  get draftStorageKey() {
    return `mesto:calculator-draft:${this.draftKeyValue}:v1`
  }
}
