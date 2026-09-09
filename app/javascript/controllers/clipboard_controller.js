import { Controller } from "@hotwired/stimulus"

const localizedCopy = (bg, en) => document.documentElement.lang.toLowerCase().startsWith("en") ? en : bg

export default class extends Controller {
  static targets = ["source", "status"]

  async copy() {
    await navigator.clipboard.writeText(this.sourceTarget.value)
    this.statusTarget.textContent = localizedCopy("Копирано", "Copied")
  }
}
