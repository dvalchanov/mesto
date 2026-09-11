import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { active: String }

  connect() {
    this.render()
  }

  activate(event) {
    event.preventDefault()
    this.select(event.currentTarget.dataset.searchMode)
  }

  navigate(event) {
    if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return

    event.preventDefault()
    const currentIndex = this.tabTargets.indexOf(event.currentTarget)
    let nextIndex = event.key === "Home" ? 0 : this.tabTargets.length - 1
    if (event.key === "ArrowLeft") nextIndex = (currentIndex - 1 + this.tabTargets.length) % this.tabTargets.length
    if (event.key === "ArrowRight") nextIndex = (currentIndex + 1) % this.tabTargets.length

    const nextTab = this.tabTargets[nextIndex]
    this.select(nextTab.dataset.searchMode)
    nextTab.focus({ preventScroll: true })
  }

  select(mode) {
    this.activeValue = mode
    this.render()
    this.remember(mode)
  }

  render() {
    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.searchMode === this.activeValue
      tab.classList.toggle("is-active", active)
      tab.setAttribute("aria-selected", String(active))
      tab.tabIndex = active ? 0 : -1
    })
    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.searchMode !== this.activeValue
    })
  }

  remember(mode) {
    const url = new URL(window.location.href)
    if (mode === "identifier") url.searchParams.set("search", mode)
    else url.searchParams.delete("search")
    window.history.replaceState(window.history.state, "", url)
  }
}
