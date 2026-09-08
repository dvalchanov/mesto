import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row"]

  connect() {
    this.rowTargets.forEach((row) => this.updateRow(row))
  }

  toggle(event) {
    const row = event.currentTarget.closest("[data-cost-editor-target='row']")
    this.updateRow(row)

    if (event.currentTarget.checked) {
      requestAnimationFrame(() => {
        const method = row?.querySelector("[data-cost-field='method']")
        method?.parentElement?.querySelector(".select-menu__trigger")?.focus()
      })
    }
  }

  changeMethod(event) {
    this.updateMethod(event.currentTarget.closest("[data-cost-editor-target='row']"))
  }

  updateRow(row) {
    if (!row) return

    const included = row.querySelector("[data-cost-field='included']")?.checked
    const fields = row.querySelector("[data-cost-fields]")
    const status = row.querySelector("[data-cost-status]")
    if (fields) fields.hidden = !included
    if (status) {
      status.textContent = included ? "Добавено към сметката" : "Не е включено"
      status.classList.toggle("is-included", included)
    }
    this.updateMethod(row)
  }

  updateMethod(row) {
    if (!row) return

    const method = row.querySelector("[data-cost-field='method']")?.value || "fixed_quote"
    row.querySelectorAll("[data-cost-method-field]").forEach((field) => {
      const acceptedMethods = field.dataset.costMethodField.split(" ")
      field.hidden = !acceptedMethods.includes(method)
    })

    const help = row.querySelector("[data-cost-method-help]")
    if (help) help.textContent = this.methodHelp(method)
    const amountLabel = row.querySelector("[data-cost-amount-label]")
    if (amountLabel) amountLabel.textContent = method === "estimate" ? "Приблизителна сума" : "Сума от офертата"
  }

  methodHelp(method) {
    return {
      fixed_quote: "Въведи крайната сума от оферта, договор или фактура.",
      percentage: "Въведи процента и върху коя сума се изчислява.",
      estimate: "Въведи ориентировъчна сума за собственото си планиране.",
      unknown: "Можеш да продължиш без сума; ще я покажем като неизвестна, а не като нула."
    }[method] || "Избери начина, по който разполагаш със стойността."
  }
}
