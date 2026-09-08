import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "template", "row", "eventSelect"]

  connect() {
    this.nextIndex = Date.now()
    this.rowTargets.forEach((row) => this.toggleAmountFields(row))
    this.refreshRowNumbers()
    this.syncEventSelectors()
  }

  applyTemplate() {
    const templates = {
      "10-10-80": [
        { key: "first", label: "Предварителен договор", amount_type: "percentage", percentage: "10" },
        { key: "second", label: "Акт 14", amount_type: "percentage", percentage: "10" },
        { key: "notarial_transfer", label: "Нотариално прехвърляне", amount_type: "remaining", percentage: "" }
      ],
      "20-80": [
        { key: "first", label: "Предварителен договор", amount_type: "percentage", percentage: "20" },
        { key: "notarial_transfer", label: "Нотариално прехвърляне", amount_type: "remaining", percentage: "" }
      ],
      "custom": [{}]
    }
    const selected = templates[this.templateTarget.value]
    if (!selected) return

    this.listTarget.innerHTML = ""
    selected.forEach((values, index) => this.appendRow({ ...values, order: String(index + 1) }))
    this.listTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  add() {
    this.appendRow({ order: String(this.rowTargets.length + 1) })
    this.rowTargets.at(-1)?.querySelector("input[data-field='label']")?.focus()
  }

  restoreRows(rows) {
    this.listTarget.innerHTML = ""
    rows.forEach((rowState) => {
      this.appendRow(rowState.values || {})
      const row = this.rowTargets.at(-1)
      const advanced = row?.querySelector(".schedule-row__advanced")
      if (advanced && typeof rowState.advancedOpen === "boolean") advanced.open = rowState.advancedOpen
    })
    this.refreshRowNumbers()
    this.syncEventSelectors()
  }

  remove(event) {
    event.currentTarget.closest("[data-schedule-editor-target='row']")?.remove()
    this.refreshRowNumbers()
    this.syncEventSelectors()
    this.listTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  changeAmountType(event) {
    this.toggleAmountFields(event.currentTarget.closest("[data-schedule-editor-target='row']"))
  }

  toggleAmountFields(row) {
    if (!row) return

    const type = row.querySelector("[data-field='amount_type']")?.value
    row.querySelectorAll("[data-amount-type-field]").forEach((field) => {
      field.hidden = field.dataset.amountTypeField !== type
    })
  }

  refreshRowNumbers() {
    this.rowTargets.forEach((row, index) => {
      const number = row.querySelector("[data-schedule-number]")
      if (number) number.textContent = String(index + 1).padStart(2, "0")
    })
  }

  syncEventSelectors(event) {
    if (event && !event.target.matches("[data-field='label']")) return
    if (!this.hasEventSelectTarget) return

    const options = this.rowTargets.map((row, index) => {
      const key = row.querySelector("[data-field='key']")?.value
      const label = row.querySelector("[data-field='label']")?.value.trim() || `Събитие ${index + 1}`
      return { key, label }
    }).filter(({ key }) => key)

    this.eventSelectTargets.forEach((select) => {
      const currentValue = select.value
      const emptyOption = Array.from(select.options).find((option) => option.value === "")
      const fallbackKey = select.dataset.scheduleEditorFallbackKey
      const fallbackLabel = select.dataset.scheduleEditorFallbackLabel
      select.replaceChildren()
      if (emptyOption) select.add(new Option(emptyOption.text, ""))
      if (fallbackKey) select.add(new Option(fallbackLabel, fallbackKey))
      options.forEach(({ key, label }) => {
        if (key !== fallbackKey) select.add(new Option(label, key))
      })
      const availableValues = Array.from(select.options).map((option) => option.value)
      if (availableValues.includes(currentValue)) select.value = currentValue
      else if (fallbackKey) select.value = fallbackKey
    })
  }

  appendRow(values) {
    const index = this.nextIndex++
    const template = document.getElementById("schedule-row-template")
    if (!template) return

    this.listTarget.insertAdjacentHTML("beforeend", template.innerHTML.replaceAll("NEW_INDEX", String(index)))
    const row = this.rowTargets.at(-1)
    if (!row) return

    const key = values.key || `event_${index}`
    Object.entries({ ...values, key }).forEach(([field, value]) => {
      const input = row.querySelector(`[data-field='${field}']`)
      if (input) input.value = value
    })
    this.toggleAmountFields(row)
    this.refreshRowNumbers()
    this.syncEventSelectors()
  }
}
