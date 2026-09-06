import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "status"]

  async copy() {
    await navigator.clipboard.writeText(this.sourceTarget.value)
    this.statusTarget.textContent = "Копирано"
  }
}
