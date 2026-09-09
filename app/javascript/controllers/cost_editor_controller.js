import { Controller } from "@hotwired/stimulus"

const localizedCopy = (bg, en) => document.documentElement.lang.toLowerCase().startsWith("en") ? en : bg

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
      status.textContent = included ? localizedCopy("Добавено към сметката", "Added to the calculation") : localizedCopy("Не е включено", "Not included")
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
    if (amountLabel) amountLabel.textContent = method === "estimate" ? localizedCopy("Приблизителна сума", "Estimated amount") : localizedCopy("Сума от офертата", "Quoted amount")
  }

  methodHelp(method) {
    const bg = {
      fixed_quote: "Въведи крайната сума от офертата, договора или фактурата.",
      percentage: "Въведи процента и върху коя сума се изчислява.",
      estimate: "Въведи ориентировъчна сума за собственото си планиране.",
      unknown: "Можеш да продължиш без сума; ще я покажем като неизвестна, а не като нула."
    }
    const en = {
      fixed_quote: "Enter the final amount shown in the quote, contract or invoice.",
      percentage: "Enter the percentage and the amount on which it is calculated.",
      estimate: "Enter an estimated amount for your own planning.",
      unknown: "You can continue without an amount; it will remain unknown rather than being counted as zero."
    }
    return localizedCopy(bg[method] || "Избери с каква информация разполагаш.", en[method] || "Choose the information you have.")
  }
}
