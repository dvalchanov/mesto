import { Controller } from "@hotwired/stimulus"
import * as maplibregl from "maplibre-gl"

export default class extends Controller {
  static targets = ["canvas"]
  static values = { payload: Object, styleUrl: String, copy: Object }

  connect() {
    const units = this.payloadValue.features.filter((feature) => feature.properties?.kind === "unit")
    if (!units.length) return

    this.map = new maplibregl.Map({
      container: this.canvasTarget,
      style: this.styleUrlValue,
      center: [23.34, 42.665],
      zoom: 17,
      attributionControl: true
    })
    this.map.addControl(new maplibregl.NavigationControl(), "top-right")
    this.map.on("load", () => this.render(units))
  }

  disconnect() {
    this.popup?.remove()
    this.map?.remove()
  }

  render(units) {
    this.map.addSource("floor-position", { type: "geojson", data: this.payloadValue })
    if (this.map.getLayer("building-3d")) this.map.setLayoutProperty("building-3d", "visibility", "none")
    this.addOverlayLayer({
      id: "position-building-fill",
      source: "floor-position",
      type: "fill",
      filter: ["==", ["get", "kind"], "building"],
      paint: { "fill-color": "#173f34", "fill-opacity": 0.08 }
    })
    this.addOverlayLayer({
      id: "position-building-line",
      source: "floor-position",
      type: "line",
      filter: ["==", ["get", "kind"], "building"],
      paint: { "line-color": "#173f34", "line-width": 3 }
    })
    this.addOverlayLayer({
      id: "position-unit-fill",
      source: "floor-position",
      type: "fill",
      filter: ["==", ["get", "kind"], "unit"],
      paint: { "fill-color": "#d88a58", "fill-opacity": 0.48 }
    })
    this.addOverlayLayer({
      id: "position-unit-line",
      source: "floor-position",
      type: "line",
      filter: ["==", ["get", "kind"], "unit"],
      paint: { "line-color": "#8b442d", "line-width": 1.5 }
    })
    this.addOverlayLayer({
      id: "position-unit-selected",
      source: "floor-position",
      type: "line",
      filter: ["==", ["get", "identifier"], ""],
      paint: { "line-color": "#173f34", "line-width": 4 }
    })

    this.map.on("click", "position-unit-fill", (event) => this.showUnit(event))
    this.map.on("mouseenter", "position-unit-fill", () => { this.map.getCanvas().style.cursor = "pointer" })
    this.map.on("mouseleave", "position-unit-fill", () => { this.map.getCanvas().style.cursor = "" })
    this.fitTo(units)
    this.map.once("idle", () => { this.element.dataset.mapReady = "true" })
  }

  addOverlayLayer(layer) {
    const styleLayers = this.map.getStyle().layers || []
    const beforeId = styleLayers.find((candidate) => candidate["source-layer"] === "transportation")?.id ||
      styleLayers.find((candidate) => candidate.type === "symbol")?.id
    if (beforeId) this.map.addLayer(layer, beforeId)
    else this.map.addLayer(layer)
  }

  fitTo(features) {
    const bounds = new maplibregl.LngLatBounds()
    const addCoordinates = (coordinates) => {
      if (typeof coordinates?.[0] === "number") bounds.extend(coordinates)
      else coordinates?.forEach(addCoordinates)
    }
    features.forEach((feature) => addCoordinates(feature.geometry?.coordinates))
    if (!bounds.isEmpty()) this.map.fitBounds(bounds, { padding: 60, maxZoom: 20, duration: 0 })
  }

  showUnit(event) {
    const feature = event.features?.[0]
    if (!feature) return

    const properties = feature.properties
    this.map.setFilter("position-unit-selected", ["==", ["get", "identifier"], properties.identifier])
    const content = document.createElement("div")
    content.className = "apartment-position__popup"
    const title = document.createElement("strong")
    title.textContent = properties.object_number
      ? this.copyValue.object.replace("%{number}", properties.object_number)
      : this.copyValue.objectUnknown
    const details = document.createElement("p")
    details.textContent = [
      properties.entrance && `${this.copyValue.entrance}: ${properties.entrance}`,
      properties.floor && `${this.copyValue.floor}: ${properties.floor}`,
      properties.area_sqm && `${this.copyValue.area}: ${properties.area_sqm} m²`
    ].filter(Boolean).join(" · ")
    const button = document.createElement("button")
    button.type = "button"
    button.className = "button button--secondary"
    button.textContent = this.copyValue.view
    button.addEventListener("click", () => this.showCandidate(properties.identifier))
    content.append(title, details, button)

    this.popup?.remove()
    this.popup = new maplibregl.Popup({ closeButton: true, maxWidth: "290px" })
      .setLngLat(event.lngLat)
      .setDOMContent(content)
      .addTo(this.map)
  }

  showCandidate(identifier) {
    const card = Array.from(document.querySelectorAll("[data-cadastral-identifier]"))
      .find((candidate) => candidate.dataset.cadastralIdentifier === identifier)
    if (!card) return

    document.querySelectorAll(".finder-candidate.is-position-highlighted")
      .forEach((candidate) => candidate.classList.remove("is-position-highlighted"))
    card.classList.add("is-position-highlighted")
    card.scrollIntoView({ behavior: "smooth", block: "center" })
    card.focus({ preventScroll: true })
  }
}
