import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { name: String, contentKey: String, mode: String }

  recordOnce() {
    if (!this.element.open || this.recorded) return

    this.recorded = true
    fetch("/product-events", {
      method: "POST",
      keepalive: true,
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: JSON.stringify({
        name: this.nameValue,
        content_key: this.contentKeyValue,
        mode: this.modeValue
      })
    })
  }
}
