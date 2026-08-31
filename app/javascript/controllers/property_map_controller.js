import { Controller } from "@hotwired/stimulus"
import maplibregl from "maplibre-gl"

export default class extends Controller {
  static targets = ["canvas"]
  static values = { payload: Object, styleUrl: String }

  connect() {
    this.map = new maplibregl.Map({
      container: this.canvasTarget,
      style: this.styleUrlValue,
      center: [23.32, 42.69],
      zoom: 12,
      attributionControl: true
    })
    this.map.addControl(new maplibregl.NavigationControl(), "top-right")
    this.map.on("load", () => this.renderData())
  }

  disconnect() {
    if (this.map) this.map.remove()
  }

  toggle(event) {
    const group = event.currentTarget.dataset.layer
    const layerIds = this.groupLayers(group)
    const visible = layerIds.some((id) => this.map.getLayer(id) && this.map.getLayoutProperty(id, "visibility") !== "none")
    layerIds.forEach((id) => {
      if (this.map.getLayer(id)) this.map.setLayoutProperty(id, "visibility", visible ? "none" : "visible")
    })
    event.currentTarget.classList.toggle("opacity-40", visible)
  }

  renderData() {
    this.map.addSource("property-data", { type: "geojson", data: this.payloadValue })

    this.addLayer({ id: "parcel-fill", type: "fill", filter: ["==", ["get", "kind"], "parcel"], paint: { "fill-color": "#059669", "fill-opacity": 0.2 } })
    this.addLayer({ id: "parcel-line", type: "line", filter: ["==", ["get", "kind"], "parcel"], paint: { "line-color": "#047857", "line-width": 3 } })
    this.addLayer({ id: "planning-fill", type: "fill", filter: ["==", ["get", "kind"], "planning"], paint: { "fill-color": "#7c3aed", "fill-opacity": 0.18 } })
    this.addLayer({ id: "planning-line", type: "line", filter: ["==", ["get", "kind"], "planning"], paint: { "line-color": "#7c3aed", "line-width": 2 } })
    this.addLayer({ id: "amenities", type: "circle", filter: ["==", ["get", "kind"], "amenity"], paint: { "circle-color": "#0284c7", "circle-radius": 5, "circle-stroke-color": "#ffffff", "circle-stroke-width": 1.5 } })
    this.addLayer({ id: "acts", type: "circle", filter: ["==", ["get", "kind"], "act"], paint: { "circle-color": "#e11d48", "circle-radius": 6, "circle-stroke-color": "#ffffff", "circle-stroke-width": 2 } })
    this.addLayer({ id: "selected", type: "circle", filter: ["==", ["get", "kind"], "selected"], paint: { "circle-color": "#064e3b", "circle-radius": 8, "circle-stroke-color": "#ffffff", "circle-stroke-width": 3 } })

    this.fitToData()
    ;["selected", "acts", "amenities", "planning-fill", "parcel-fill"].forEach((id) => {
      this.map.on("click", id, (event) => this.showPopup(event))
      this.map.on("mouseenter", id, () => { this.map.getCanvas().style.cursor = "pointer" })
      this.map.on("mouseleave", id, () => { this.map.getCanvas().style.cursor = "" })
    })
  }

  addLayer(layer) {
    this.map.addLayer({ ...layer, source: "property-data" })
  }

  groupLayers(group) {
    return {
      selected: ["selected", "parcel-fill", "parcel-line"],
      planning: ["planning-fill", "planning-line"],
      acts: ["acts"],
      amenities: ["amenities"]
    }[group] || []
  }

  fitToData() {
    const coordinates = []
    this.payloadValue.features.forEach((feature) => this.collectCoordinates(feature.geometry.coordinates, coordinates))
    if (coordinates.length === 0) return
    if (coordinates.length === 1) {
      this.map.flyTo({ center: coordinates[0], zoom: 16 })
      return
    }

    const bounds = coordinates.reduce((box, coordinate) => box.extend(coordinate), new maplibregl.LngLatBounds(coordinates[0], coordinates[0]))
    this.map.fitBounds(bounds, { padding: 48, maxZoom: 16, duration: 0 })
  }

  collectCoordinates(value, target) {
    if (!Array.isArray(value)) return
    if (typeof value[0] === "number" && typeof value[1] === "number") target.push(value)
    else value.forEach((entry) => this.collectCoordinates(entry, target))
  }

  showPopup(event) {
    const feature = event.features[0]
    const wrapper = document.createElement("div")
    const title = document.createElement("strong")
    title.textContent = feature.properties.label || feature.properties.category || feature.properties.source_key || ""
    wrapper.appendChild(title)
    if (feature.properties.source_url && /^https:\/\//.test(feature.properties.source_url)) {
      const link = document.createElement("a")
      link.href = feature.properties.source_url
      link.target = "_blank"
      link.rel = "noopener noreferrer"
      link.textContent = " ↗"
      wrapper.appendChild(link)
    }
    new maplibregl.Popup().setLngLat(event.lngLat).setDOMContent(wrapper).addTo(this.map)
  }
}
