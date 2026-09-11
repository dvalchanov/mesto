import { Controller } from "@hotwired/stimulus"

const localizedCopy = (bg, en) => document.documentElement.lang.toLowerCase().startsWith("en") ? en : bg

export default class extends Controller {
  static targets = ["source", "status"]

  async copy() {
    const value = this.sourceTarget.value ?? this.sourceTarget.textContent.trim()

    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(value)
      } else {
        this.copyWithFallback(value)
      }
      this.statusTarget.textContent = localizedCopy("Копирано", "Copied")
    } catch {
      this.selectSource()
      this.statusTarget.textContent = localizedCopy("Копирай ръчно", "Copy manually")
    }
  }

  copyWithFallback(value) {
    const textarea = document.createElement("textarea")
    textarea.value = value
    textarea.setAttribute("readonly", "")
    textarea.style.position = "fixed"
    textarea.style.opacity = "0"
    document.body.appendChild(textarea)
    textarea.select()
    const copied = document.execCommand("copy")
    textarea.remove()
    if (!copied) throw new Error("Copy command failed")
  }

  selectSource() {
    if (this.sourceTarget.select) {
      this.sourceTarget.select()
      return
    }

    const selection = window.getSelection()
    const range = document.createRange()
    range.selectNodeContents(this.sourceTarget)
    selection.removeAllRanges()
    selection.addRange(range)
  }
}
