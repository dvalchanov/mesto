import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (window.location.hash === this.element.hash) this.openTarget({ focus: false })
  }

  open(event) {
    event.preventDefault()
    this.openTarget({ focus: true })
  }

  openTarget({ focus }) {
    const details = document.querySelector(this.element.hash)
    if (!(details instanceof HTMLDetailsElement)) return

    details.open = true
    window.history.replaceState(null, "", this.element.hash)
    details.scrollIntoView({
      behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth",
      block: "center"
    })
    if (focus) details.querySelector("summary")?.focus({ preventScroll: true })
  }
}
