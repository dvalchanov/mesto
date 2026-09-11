import { Controller } from "@hotwired/stimulus"
import * as maplibregl from "maplibre-gl"

export default class extends Controller {
  static targets = [
    "form", "addressInput", "buildingInput", "methodInput", "suggestions", "selection",
    "dialog", "mapCanvas", "mapInput", "mapStatus"
  ]
  static values = {
    suggestionsUrl: String,
    buildingsUrl: String,
    styleUrl: String,
    copy: Object
  }

  connect() {
    this.suggestionIndex = -1
    this.mapDataReady = false
    this.initialViewportResolved = false
    this.handleOutsidePointer = (event) => {
      if (!this.suggestionsTarget.contains(event.target) && event.target !== this.addressInputTarget) {
        this.closeSuggestions()
      }
    }
    document.addEventListener("pointerdown", this.handleOutsidePointer)
  }

  disconnect() {
    document.removeEventListener("pointerdown", this.handleOutsidePointer)
    clearTimeout(this.suggestionTimer)
    this.suggestionRequest?.abort()
    this.mapRequest?.abort()
    this.popup?.remove()
    this.map?.remove()
  }

  suggest() {
    this.clearSelectedBuilding()
    clearTimeout(this.suggestionTimer)
    const query = this.addressInputTarget.value.trim()
    if (query.length < 2) return this.closeSuggestions()

    this.suggestionTimer = setTimeout(() => this.fetchSuggestions(query), 180)
  }

  refreshSuggestions() {
    if (this.addressInputTarget.value.trim().length >= 2) this.suggest()
  }

  navigateSuggestions(event) {
    const options = Array.from(this.suggestionsTarget.querySelectorAll("[role='option']"))

    if (event.key === "ArrowDown" && options.length) {
      event.preventDefault()
      this.suggestionIndex = (this.suggestionIndex + 1) % options.length
      this.activateSuggestion(options)
    } else if (event.key === "ArrowUp" && options.length) {
      event.preventDefault()
      this.suggestionIndex = (this.suggestionIndex - 1 + options.length) % options.length
      this.activateSuggestion(options)
    } else if (event.key === "Enter" && this.suggestionIndex >= 0) {
      event.preventDefault()
      options[this.suggestionIndex]?.click()
    } else if (event.key === "Escape") {
      this.closeSuggestions()
    }
  }

  async fetchSuggestions(query) {
    this.suggestionRequest?.abort()
    this.suggestionRequest = new AbortController()

    try {
      const url = new URL(this.suggestionsUrlValue, window.location.origin)
      url.searchParams.set("q", query)
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        signal: this.suggestionRequest.signal
      })
      if (!response.ok) throw new Error(`Suggestion request failed: ${response.status}`)

      const payload = await response.json()
      if (query !== this.addressInputTarget.value.trim()) return
      this.renderSuggestions(payload.suggestions || [])
    } catch (error) {
      if (error.name !== "AbortError") this.closeSuggestions()
    }
  }

  renderSuggestions(suggestions) {
    this.suggestions = suggestions
    this.suggestionIndex = -1
    this.suggestionsTarget.replaceChildren(...suggestions.map((suggestion, index) => {
      const option = document.createElement("button")
      option.type = "button"
      option.className = "property-locator__suggestion"
      option.setAttribute("role", "option")
      option.setAttribute("aria-selected", "false")
      option.id = `${this.suggestionsTarget.id}-option-${index}`
      option.dataset.index = index

      const address = document.createElement("span")
      address.className = "property-locator__suggestion-address"
      address.textContent = suggestion.address
      const count = document.createElement("span")
      count.className = "property-locator__suggestion-count"
      count.textContent = suggestion.building_count_label
      option.append(address, count)
      option.addEventListener("pointerdown", (event) => event.preventDefault())
      option.addEventListener("click", () => this.chooseSuggestion(suggestion))
      return option
    }))

    this.suggestionsTarget.hidden = suggestions.length === 0
    this.addressInputTarget.setAttribute("aria-expanded", String(suggestions.length > 0))
  }

  activateSuggestion(options) {
    options.forEach((option, index) => {
      const active = index === this.suggestionIndex
      option.classList.toggle("is-active", active)
      option.setAttribute("aria-selected", String(active))
    })
    const active = options[this.suggestionIndex]
    if (active) {
      active.scrollIntoView({ block: "nearest" })
      this.addressInputTarget.setAttribute("aria-activedescendant", active.id)
    }
  }

  chooseSuggestion(suggestion) {
    this.addressInputTarget.value = suggestion.address
    this.closeSuggestions()

    if (suggestion.building_identifier) {
      this.buildingInputTarget.value = suggestion.building_identifier
      if (this.hasMethodInputTarget) this.methodInputTarget.value = "autocomplete"
      this.showSelection(suggestion.building_count_label)
    } else {
      this.clearSelectedBuilding()
      this.openMap()
    }
  }

  closeSuggestions() {
    this.suggestionsTarget.hidden = true
    this.suggestionsTarget.replaceChildren()
    this.suggestionIndex = -1
    this.addressInputTarget.setAttribute("aria-expanded", "false")
    this.addressInputTarget.removeAttribute("aria-activedescendant")
  }

  clearSelectedBuilding() {
    if (this.hasBuildingInputTarget) this.buildingInputTarget.value = ""
    if (this.hasMethodInputTarget) this.methodInputTarget.value = "address"
    if (this.hasSelectionTarget) this.selectionTarget.hidden = true
  }

  showSelection(label) {
    if (!this.hasSelectionTarget) return

    this.selectionTarget.textContent = `${this.copyValue.selected}: ${label}`
    this.selectionTarget.hidden = false
  }

  openMap(event) {
    event?.preventDefault()
    this.closeSuggestions()
    this.mapInputTarget.value = this.addressInputTarget.value
    if (!this.dialogTarget.open) this.dialogTarget.showModal()

    if (this.map) {
      requestAnimationFrame(() => {
        this.map.resize()
        this.loadMapFromInput()
      })
    } else {
      this.initializeMap()
    }
  }

  closeMap() {
    this.popup?.remove()
    this.dialogTarget.close()
  }

  searchMap(event) {
    if (event?.type === "keydown" && event.key !== "Enter") return
    event?.preventDefault()

    const query = this.mapInputTarget.value.trim()
    this.addressInputTarget.value = query
    this.clearSelectedBuilding()
    this.loadMapFromInput()
  }

  initializeMap() {
    this.map = new maplibregl.Map({
      container: this.mapCanvasTarget,
      style: this.styleUrlValue,
      center: [23.3512, 42.6475],
      zoom: 17,
      attributionControl: true
    })
    this.map.addControl(new maplibregl.NavigationControl(), "top-right")
    this.map.addControl(new maplibregl.ScaleControl({ maxWidth: 100, unit: "metric" }), "bottom-left")
    this.map.on("load", () => {
      this.map.addSource("locator-buildings", {
        type: "geojson",
        data: { type: "FeatureCollection", features: [] }
      })
      if (this.map.getLayer("building-3d")) this.map.setLayoutProperty("building-3d", "visibility", "none")
      this.addOverlayLayer({
        id: "locator-building-fill",
        source: "locator-buildings",
        type: "fill",
        paint: { "fill-color": "#789565", "fill-opacity": 0.34 }
      })
      this.addOverlayLayer({
        id: "locator-building-line",
        source: "locator-buildings",
        type: "line",
        paint: { "line-color": "#173f34", "line-width": 1.7 }
      })
      this.addOverlayLayer({
        id: "locator-building-selected",
        source: "locator-buildings",
        type: "line",
        filter: ["==", ["get", "identifier"], ""],
        paint: { "line-color": "#bf5f3e", "line-width": 4 }
      })

      this.map.on("click", "locator-building-fill", (mapEvent) => this.showBuilding(mapEvent))
      this.map.on("mouseenter", "locator-building-fill", () => { this.map.getCanvas().style.cursor = "pointer" })
      this.map.on("mouseleave", "locator-building-fill", () => { this.map.getCanvas().style.cursor = "" })
      this.map.on("moveend", () => {
        if (this.ignoreNextMove) this.ignoreNextMove = false
        else if (!this.mapQueryActive) this.loadViewportBuildings()
      })
      this.map.once("idle", () => { this.dialogTarget.dataset.mapReady = "true" })
      this.mapDataReady = true
      this.loadMapFromInput()
    })
  }

  loadMapFromInput() {
    if (!this.mapDataReady) return

    const query = this.mapInputTarget.value.trim()
    if (query.length >= 2) {
      this.mapQueryActive = true
      this.fetchBuildings({ q: query }, true)
    } else if (!this.initialViewportResolved) {
      this.loadInitialViewport()
    } else {
      this.mapQueryActive = false
      this.loadViewportBuildings()
    }
  }

  addOverlayLayer(layer) {
    const styleLayers = this.map.getStyle().layers || []
    const beforeId = styleLayers.find((candidate) => candidate["source-layer"] === "transportation")?.id ||
      styleLayers.find((candidate) => candidate.type === "symbol")?.id
    if (beforeId) this.map.addLayer(layer, beforeId)
    else this.map.addLayer(layer)
  }

  loadViewportBuildings() {
    if (!this.mapDataReady) return
    if (this.map.getZoom() < 15) {
      this.setMapData({ type: "FeatureCollection", features: [] })
      this.dialogTarget.dataset.buildingCount = "0"
      this.mapStatusTarget.textContent = this.copyValue.zoom
      return
    }

    const bounds = this.map.getBounds()
    this.fetchBuildings({
      bbox: [bounds.getWest(), bounds.getSouth(), bounds.getEast(), bounds.getNorth()].join(",")
    }, false)
  }

  async loadInitialViewport() {
    this.initialViewportResolved = true
    this.mapQueryActive = false
    this.mapRequest?.abort()
    this.mapRequest = new AbortController()
    this.mapStatusTarget.textContent = this.copyValue.loading

    try {
      const url = new URL(this.buildingsUrlValue, window.location.origin)
      url.searchParams.set("initial", "true")
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        signal: this.mapRequest.signal
      })
      if (!response.ok) throw new Error(`Initial building request failed: ${response.status}`)

      const payload = await response.json()
      const center = payload.meta?.center
      if (Array.isArray(center) && center.length === 2) {
        this.ignoreNextMove = true
        this.map.jumpTo({ center, zoom: 17 })
      }
      this.loadViewportBuildings()
    } catch (error) {
      if (error.name !== "AbortError") this.loadViewportBuildings()
    }
  }

  async fetchBuildings(parameters, fit) {
    this.mapRequest?.abort()
    this.mapRequest = new AbortController()
    this.mapStatusTarget.textContent = this.copyValue.loading

    try {
      const url = new URL(this.buildingsUrlValue, window.location.origin)
      Object.entries(parameters).forEach(([key, value]) => url.searchParams.set(key, value))
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        signal: this.mapRequest.signal
      })
      if (!response.ok) throw new Error(`Building request failed: ${response.status}`)

      const payload = await response.json()
      this.setMapData(payload)
      const count = payload.meta?.count || 0
      this.dialogTarget.dataset.buildingCount = String(count)
      this.mapStatusTarget.textContent = count === 0
        ? this.copyValue.noResults
        : this.copyValue.results.replace("%{count}", count) + (payload.meta?.truncated ? ` ${this.copyValue.truncated}` : "")
      if (fit && count > 0) this.fitToFeatures(payload.features)
    } catch (error) {
      if (error.name !== "AbortError") this.mapStatusTarget.textContent = this.copyValue.error
    }
  }

  setMapData(payload) {
    this.map?.getSource("locator-buildings")?.setData(payload)
  }

  fitToFeatures(features) {
    const bounds = this.boundsFor(features)
    if (!bounds || bounds.isEmpty()) return

    this.ignoreNextMove = true
    this.map.fitBounds(bounds, { padding: 58, maxZoom: 18.5, duration: 500 })
  }

  boundsFor(features) {
    const bounds = new maplibregl.LngLatBounds()
    const addCoordinates = (coordinates) => {
      if (typeof coordinates?.[0] === "number") bounds.extend(coordinates)
      else coordinates?.forEach(addCoordinates)
    }
    features.forEach((feature) => addCoordinates(feature.geometry?.coordinates))
    return bounds
  }

  showBuilding(event) {
    const feature = event.features?.[0]
    if (!feature) return

    this.popup?.remove()
    this.map.setFilter("locator-building-selected", ["==", ["get", "identifier"], feature.properties.identifier])
    const content = document.createElement("div")
    content.className = "property-locator__popup"
    const title = document.createElement("strong")
    title.textContent = feature.properties.address || this.copyValue.unknownAddress
    const identifier = document.createElement("code")
    identifier.textContent = feature.properties.identifier
    const button = document.createElement("button")
    button.type = "button"
    button.className = "button button--secondary"
    button.textContent = this.copyValue.choose
    button.addEventListener("click", () => this.selectBuilding(feature.properties))
    content.append(title, identifier, button)

    const popup = new maplibregl.Popup({ closeButton: true, maxWidth: "310px" })
      .setLngLat(event.lngLat)
      .setDOMContent(content)
      .addTo(this.map)
    popup.on("close", () => {
      if (this.popup !== popup) return

      this.popup = null
      if (this.map?.getLayer("locator-building-selected")) {
        this.map.setFilter("locator-building-selected", ["==", ["get", "identifier"], ""])
      }
    })
    this.popup = popup
  }

  selectBuilding(properties) {
    this.addressInputTarget.value = properties.address || this.addressInputTarget.value
    this.buildingInputTarget.value = properties.identifier
    if (this.hasMethodInputTarget) this.methodInputTarget.value = "map"
    this.closeMap()
    this.formTarget.requestSubmit()
  }
}
