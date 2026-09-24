import { Controller } from "@hotwired/stimulus"

// Plays the landing-page explainer only while it is on screen. Visitors who
// prefer reduced motion see the poster until they choose to play it.
export default class extends Controller {
  static targets = ["video", "toggle"]
  static values = { playLabel: String, pauseLabel: String }

  connect() {
    this.userPaused = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.visible = false
    this.observer = new IntersectionObserver(([entry]) => {
      this.visible = entry.isIntersecting
      this.sync()
    }, { threshold: 0.35 })
    this.observer.observe(this.element)
    this.render()
  }

  disconnect() {
    this.observer?.disconnect()
    this.videoTarget.pause()
  }

  toggle() {
    this.userPaused = !this.videoTarget.paused
    if (this.userPaused) {
      this.videoTarget.pause()
    } else {
      this.play()
    }
  }

  sync() {
    if (this.visible && !this.userPaused) {
      this.play()
    } else {
      this.videoTarget.pause()
    }
  }

  play() {
    this.videoTarget.play().catch(() => this.render())
  }

  render() {
    const playing = !this.videoTarget.paused
    this.toggleTarget.dataset.state = playing ? "playing" : "paused"
    this.toggleTarget.setAttribute("aria-label", playing ? this.pauseLabelValue : this.playLabelValue)
  }
}
