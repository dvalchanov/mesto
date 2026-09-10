import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas", "diagram", "edge", "node", "panel"]

  connect() {
    this.drawnEdges = []
    this.hasUserSelection = false
    this.showNode(this.nodeTargets[0]?.dataset.nodeKey)
    this.resizeObserver = new ResizeObserver(() => this.draw())
    if (this.hasDiagramTarget) this.resizeObserver.observe(this.diagramTarget)
    requestAnimationFrame(() => this.draw())
  }

  disconnect() {
    this.resizeObserver?.disconnect()
  }

  select(event) {
    this.hasUserSelection = true
    this.showNode(event.currentTarget.dataset.nodeKey)
  }

  showNode(key) {
    if (!key) return

    this.selectedNodeKey = key
    this.nodeTargets.forEach((node) => {
      const selected = node.dataset.nodeKey === key
      node.setAttribute("aria-pressed", selected.toString())
      node.classList.toggle("is-selected", selected)
    })
    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.nodeKey !== key
    })
    this.updateEdgeFocus()
  }

  draw() {
    if (!this.hasCanvasTarget || !this.hasDiagramTarget || this.diagramTarget.offsetParent === null) return

    const diagramRect = this.diagramTarget.getBoundingClientRect()
    const nodeMap = new Map(this.nodeTargets.map((node) => [node.dataset.nodeKey, node]))
    const nodeBoxes = this.nodeTargets.map((node) => this.localRect(node.getBoundingClientRect(), diagramRect))
    this.canvasTarget.replaceChildren()
    this.canvasTarget.setAttribute("viewBox", `0 0 ${diagramRect.width} ${diagramRect.height}`)
    this.addArrowMarker()
    this.drawnEdges = []
    const occupiedLabels = []
    const visualEdges = new Map()

    this.edgeTargets.forEach((edge) => {
      const key = [edge.dataset.subjectKey, edge.dataset.objectKey, edge.dataset.label, edge.dataset.active].join("|")
      if (!visualEdges.has(key)) visualEdges.set(key, edge)
    })

    visualEdges.forEach((edge) => {
      const subject = nodeMap.get(edge.dataset.subjectKey)
      const object = nodeMap.get(edge.dataset.objectKey)
      if (!subject || !object) return

      const subjectRect = this.localRect(subject.getBoundingClientRect(), diagramRect)
      const objectRect = this.localRect(object.getBoundingClientRect(), diagramRect)
      const from = this.pointAtRectEdge(subjectRect, objectRect, 9)
      const to = this.pointAtRectEdge(objectRect, subjectRect, 12)
      const line = this.svg("line", {
        x1: from.x, y1: from.y, x2: to.x, y2: to.y,
        stroke: edge.dataset.active === "true" ? "#55705f" : "#94a3a0",
        "stroke-width": "1.6",
        "stroke-linecap": "round",
        "stroke-dasharray": edge.dataset.active === "true" ? "" : "5 5",
        "marker-end": "url(#property-graph-arrow)",
        "vector-effect": "non-scaling-stroke"
      })
      this.canvasTarget.append(line)

      const labelWidth = Math.min(250, Math.max(96, edge.dataset.label.length * 7 + 28))
      const labelPoint = this.labelPoint(
        from, to, labelWidth, nodeBoxes, occupiedLabels,
        { width: diagramRect.width, height: diagramRect.height }
      )
      const elements = [line]
      if (labelPoint) {
        const labelGroup = this.svg("g", {
          "data-edge-label": "true"
        })
        labelGroup.append(this.svg("rect", {
          x: labelPoint.x - labelWidth / 2,
          y: labelPoint.y - 11,
          width: labelWidth,
          height: 22,
          rx: 11,
          fill: "#ffffff",
          stroke: "#dce5df",
          "stroke-width": "1"
        }))
        const label = this.svg("text", {
          x: labelPoint.x,
          y: labelPoint.y + 3.5,
          "text-anchor": "middle",
          fill: "#42564c",
          "font-size": "10.5",
          "font-weight": "700"
        })
        label.textContent = edge.dataset.label
        labelGroup.append(label)
        this.canvasTarget.append(labelGroup)
        elements.push(labelGroup)
      }
      this.drawnEdges.push({
        subjectKey: edge.dataset.subjectKey,
        objectKey: edge.dataset.objectKey,
        elements
      })
    })
    this.updateEdgeFocus()
  }

  addArrowMarker() {
    const defs = this.svg("defs", {})
    const marker = this.svg("marker", {
      id: "property-graph-arrow",
      viewBox: "0 0 8 8",
      refX: "7",
      refY: "4",
      markerWidth: "6",
      markerHeight: "6",
      orient: "auto-start-reverse"
    })
    marker.append(this.svg("path", { d: "M 0 0 L 8 4 L 0 8 z", fill: "#55705f" }))
    defs.append(marker)
    this.canvasTarget.append(defs)
  }

  updateEdgeFocus() {
    if (!this.drawnEdges?.length) return

    this.drawnEdges.forEach((edge) => {
      const connected = edge.subjectKey === this.selectedNodeKey || edge.objectKey === this.selectedNodeKey
      edge.elements.forEach((element) => {
        if (!this.hasUserSelection || connected) {
          element.style.opacity = "1"
        } else {
          element.style.opacity = element.tagName === "line" ? "0.32" : "0.68"
        }
      })
    })
  }

  localRect(rect, container) {
    return {
      left: rect.left - container.left,
      top: rect.top - container.top,
      right: rect.right - container.left,
      bottom: rect.bottom - container.top,
      width: rect.width,
      height: rect.height,
      centerX: rect.left - container.left + rect.width / 2,
      centerY: rect.top - container.top + rect.height / 2
    }
  }

  pointAtRectEdge(from, toward, padding) {
    const dx = toward.centerX - from.centerX
    const dy = toward.centerY - from.centerY
    const scaleX = dx === 0 ? Number.POSITIVE_INFINITY : (from.width / 2 + padding) / Math.abs(dx)
    const scaleY = dy === 0 ? Number.POSITIVE_INFINITY : (from.height / 2 + padding) / Math.abs(dy)
    const scale = Math.min(scaleX, scaleY)
    return { x: from.centerX + dx * scale, y: from.centerY + dy * scale }
  }

  labelPoint(from, to, width, nodeBoxes, occupiedLabels, bounds) {
    const dx = to.x - from.x
    const dy = to.y - from.y
    const length = Math.hypot(dx, dy) || 1
    const normal = { x: -dy / length, y: dx / length }
    const candidates = [
      [0.5, -17], [0.35, -17], [0.65, -17], [0.5, 17],
      [0.25, -17], [0.75, -17], [0.35, 30], [0.65, 30],
      [0.5, -76], [0.5, 76], [0.35, -76], [0.65, 76],
      [0.25, -92], [0.75, 92]
    ]
    for (const [progress, offset] of candidates) {
      const point = {
        x: from.x + dx * progress + normal.x * offset,
        y: from.y + dy * progress + normal.y * offset
      }
      const box = {
        left: point.x - width / 2,
        right: point.x + width / 2,
        top: point.y - 11,
        bottom: point.y + 11
      }
      const blockedByNode = nodeBoxes.some((node) => this.rectsOverlap(box, {
        left: node.left - 8,
        right: node.right + 8,
        top: node.top - 8,
        bottom: node.bottom + 8
      }))
      const blockedByLabel = occupiedLabels.some((label) => this.rectsOverlap(box, label))
      const outsideCanvas = box.left < 10 || box.right > bounds.width - 10 || box.top < 10 || box.bottom > bounds.height - 10
      if (!blockedByNode && !blockedByLabel && !outsideCanvas) {
        occupiedLabels.push(box)
        return point
      }
    }

    return null
  }

  rectsOverlap(left, right) {
    return left.left < right.right && left.right > right.left && left.top < right.bottom && left.bottom > right.top
  }

  svg(name, attributes) {
    const element = document.createElementNS("http://www.w3.org/2000/svg", name)
    Object.entries(attributes).forEach(([key, value]) => element.setAttribute(key, value))
    return element
  }
}
