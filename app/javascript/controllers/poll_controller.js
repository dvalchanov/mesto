import { Controller } from "@hotwired/stimulus"
import * as Turbo from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = { active: Boolean }

  connect() {
    if (!this.activeValue) return

    this.timer = window.setInterval(() => {
      if (document.visibilityState === "visible") Turbo.visit(window.location.href, { action: "replace" })
    }, 2500)
  }

  disconnect() {
    if (this.timer) window.clearInterval(this.timer)
  }
}
