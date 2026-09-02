import { Controller } from "@hotwired/stimulus"
import maplibregl from "maplibre-gl"

export default class extends Controller {
  static targets = ["canvas"]
  static values = { payload: Object, styleUrl: String, sourceLabel: String }

  connect() {
    this.map = new maplibregl.Map({
      container: this.canvasTarget,
      style: this.styleUrlValue,
      center: [23.32, 42.69],
      zoom: 12,
      attributionControl: true
    })
    this.map.addControl(new maplibregl.NavigationControl(), "top-right")
    this.map.addControl(new maplibregl.ScaleControl({ maxWidth: 100, unit: "metric" }), "bottom-left")
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
    event.currentTarget.setAttribute("aria-pressed", visible ? "false" : "true")
  }

  renderData() {
    this.map.addSource("property-data", { type: "geojson", data: this.payloadValue })
    this.overlayBeforeId = this.findOverlayAnchor()
    if (this.map.getLayer("building-3d")) this.map.setLayoutProperty("building-3d", "visibility", "none")

    this.addOverlayLayer({ id: "planning-fill", type: "fill", filter: ["==", ["get", "kind"], "planning"], layout: { visibility: "none" }, paint: { "fill-color": "#b95f3f", "fill-opacity": 0.16 } })
    this.addOverlayLayer({ id: "planning-line", type: "line", filter: ["==", ["get", "kind"], "planning"], layout: { visibility: "none" }, paint: { "line-color": "#b95f3f", "line-width": 2 } })

    this.addOverlayLayer({ id: "flood-fill", type: "fill", filter: this.amenityFilter("flood_risk"), layout: { visibility: "none" }, paint: { "fill-color": "#3f83a8", "fill-opacity": 0.16 } })
    this.addOverlayLayer({ id: "flood-line", type: "line", filter: this.amenityFilter("flood_risk"), layout: { visibility: "none" }, paint: { "line-color": "#3f83a8", "line-width": 1.5 } })
    this.addOverlayLayer({ id: "green-space-fill", type: "fill", filter: this.amenityFilter("green_spaces"), paint: { "fill-color": "#789565", "fill-opacity": 0.18 } })
    this.addOverlayLayer({ id: "green-space-line", type: "line", filter: this.amenityFilter("green_spaces"), paint: { "line-color": "#5e7b4d", "line-width": 1.5 } })

    this.addOverlayLayer({ id: "parcel-fill", type: "fill", filter: ["==", ["get", "kind"], "parcel"], paint: { "fill-color": "#d7b56d", "fill-opacity": 0.1 } })
    this.addOverlayLayer({ id: "parcel-line", type: "line", filter: ["==", ["get", "kind"], "parcel"], paint: { "line-color": "#9a7435", "line-width": 2, "line-dasharray": [3, 2] } })
    this.addOverlayLayer({ id: "nearby-buildings-fill", type: "fill", filter: ["==", ["get", "kind"], "nearby_building"], paint: { "fill-color": "#7b8580", "fill-opacity": 0.13 } })
    this.addOverlayLayer({ id: "nearby-buildings-line", type: "line", filter: ["==", ["get", "kind"], "nearby_building"], paint: { "line-color": "#66716c", "line-width": 1 } })
    this.addOverlayLayer({ id: "selected-building-fill", type: "fill", filter: ["==", ["get", "kind"], "selected_building"], paint: { "fill-color": "#173f34", "fill-opacity": 0.28 } })
    this.addOverlayLayer({ id: "selected-building-line", type: "line", filter: ["==", ["get", "kind"], "selected_building"], paint: { "line-color": "#173f34", "line-width": 3 } })
    this.addOverlayLayer({ id: "selected-object-fill", type: "fill", filter: ["==", ["get", "kind"], "selected_object"], paint: { "fill-color": "#df8a52", "fill-opacity": 0.42 } })
    this.addOverlayLayer({ id: "selected-object-line", type: "line", filter: ["==", ["get", "kind"], "selected_object"], paint: { "line-color": "#a94e2f", "line-width": 3 } })

    this.addLayer({ id: "green-space-points", type: "circle", filter: this.pointAmenityFilter("green_spaces"), paint: { "circle-color": "#5e7b4d", "circle-radius": 6, "circle-stroke-color": "#fffefb", "circle-stroke-width": 2 } })
    this.addLayer({ id: "schools", type: "circle", filter: this.pointAmenityFilter("schools"), paint: { "circle-color": "#52646b", "circle-radius": 6, "circle-stroke-color": "#fffefb", "circle-stroke-width": 2 } })
    this.addLayer({ id: "kindergartens", type: "circle", filter: this.pointAmenityFilter("kindergartens"), paint: { "circle-color": "#b95f3f", "circle-radius": 6, "circle-stroke-color": "#fffefb", "circle-stroke-width": 2 } })
    this.addLayer({ id: "transit", type: "circle", filter: this.pointAmenityFilter("transit"), paint: { "circle-color": "#b95f3f", "circle-radius": 6, "circle-stroke-color": "#fffefb", "circle-stroke-width": 2 } })
    this.addLayer({ id: "acts", type: "circle", filter: ["==", ["get", "kind"], "act"], layout: { visibility: "none" }, paint: { "circle-color": "#b95f3f", "circle-radius": 6, "circle-stroke-color": "#fffefb", "circle-stroke-width": 2 } })
    this.addLayer({ id: "selected-location", type: "circle", filter: ["==", ["get", "kind"], "selected_location"], paint: { "circle-color": "#fffefb", "circle-radius": 6, "circle-stroke-color": "#173f34", "circle-stroke-width": 4 } })

    this.fitToData()
    const clickableLayers = [
      "selected-location", "selected-object-fill", "selected-building-fill", "parcel-fill",
      "nearby-buildings-fill", "schools", "kindergartens", "transit", "green-space-fill",
      "green-space-points", "flood-fill", "acts", "planning-fill"
    ]
    const basePoiLayers = ["poi_r20", "poi_r7", "poi_r1", "poi_transit"].filter((id) => this.map.getLayer(id))
    const interactiveLayers = [...clickableLayers, ...basePoiLayers]
    this.map.on("click", (event) => {
      const feature = this.map.queryRenderedFeatures(event.point, { layers: interactiveLayers })[0]
      if (feature) this.showPopup(event, feature)
    })
    this.map.on("mousemove", (event) => {
      const hasFeature = this.map.queryRenderedFeatures(event.point, { layers: interactiveLayers }).length > 0
      this.map.getCanvas().style.cursor = hasFeature ? "pointer" : ""
    })
  }

  addLayer(layer) {
    this.map.addLayer({ ...layer, source: "property-data" })
  }

  addOverlayLayer(layer) {
    const sourceLayer = { ...layer, source: "property-data" }
    if (this.overlayBeforeId) this.map.addLayer(sourceLayer, this.overlayBeforeId)
    else this.map.addLayer(sourceLayer)
  }

  findOverlayAnchor() {
    const layers = this.map.getStyle().layers || []
    return layers.find((layer) => layer["source-layer"] === "transportation")?.id ||
      layers.find((layer) => layer.type === "symbol")?.id
  }

  amenityFilter(category) {
    return ["all", ["==", ["get", "kind"], "amenity"], ["==", ["get", "category"], category]]
  }

  pointAmenityFilter(category) {
    return ["all", ...this.amenityFilter(category).slice(1), ["==", ["geometry-type"], "Point"]]
  }

  groupLayers(group) {
    return {
      selected: ["selected-location", "selected-object-fill", "selected-object-line", "selected-building-fill", "selected-building-line", "parcel-fill", "parcel-line"],
      buildings: ["nearby-buildings-fill", "nearby-buildings-line"],
      schools: ["schools"],
      kindergartens: ["kindergartens"],
      green_spaces: ["green-space-fill", "green-space-line", "green-space-points"],
      transit: ["transit"],
      planning: ["planning-fill", "planning-line"],
      acts: ["acts"],
      flood: ["flood-fill", "flood-line"]
    }[group] || []
  }

  fitToData() {
    const coordinates = []
    const focusFeatures = this.payloadValue.features.filter((feature) => feature.properties.focus === true)
    const features = focusFeatures.length > 0 ? focusFeatures : this.payloadValue.features
    features.forEach((feature) => this.collectCoordinates(feature.geometry.coordinates, coordinates))
    if (coordinates.length === 0) return
    if (coordinates.length === 1) {
      this.map.flyTo({ center: coordinates[0], zoom: 16.5 })
      return
    }

    const bounds = coordinates.reduce((box, coordinate) => box.extend(coordinate), new maplibregl.LngLatBounds(coordinates[0], coordinates[0]))
    this.map.fitBounds(bounds, { padding: 56, maxZoom: 16.5, duration: 0 })
  }

  collectCoordinates(value, target) {
    if (!Array.isArray(value)) return
    if (typeof value[0] === "number" && typeof value[1] === "number") target.push(value)
    else value.forEach((entry) => this.collectCoordinates(entry, target))
  }

  showPopup(event, feature) {
    const wrapper = document.createElement("div")
    const title = document.createElement("strong")
    title.textContent = feature.properties.type_label || feature.properties.name || feature.properties["name:nonlatin"] || feature.properties["name:latin"] || feature.properties.category || feature.properties.class || feature.properties.source_key || ""
    wrapper.appendChild(title)
    ;["label", "detail", "address", "distance_label", "date_label"].forEach((key) => {
      if (!feature.properties[key]) return

      const line = document.createElement("div")
      line.textContent = feature.properties[key]
      wrapper.appendChild(line)
    })
    if (feature.properties.source_url && /^https:\/\//.test(feature.properties.source_url)) {
      const link = document.createElement("a")
      link.href = feature.properties.source_url
      link.target = "_blank"
      link.rel = "noopener noreferrer"
      link.textContent = `${this.sourceLabelValue} ↗`
      link.className = "map-popup-source"
      wrapper.appendChild(link)
    }
    new maplibregl.Popup().setLngLat(event.lngLat).setDOMContent(wrapper).addTo(this.map)
  }
}
