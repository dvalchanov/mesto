import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  show(event) {
    const section = event.currentTarget.dataset.section
    this.tabTargets.forEach((tab) => tab.setAttribute("aria-selected", String(tab.dataset.section === section)))
    this.panelTargets.forEach((panel) => { panel.hidden = panel.dataset.section !== section })
    event.currentTarget.focus()
  }
}
