import { Controller } from "@hotwired/stimulus"

const NATIVE_PICKER_QUERY = "(max-width: 760px), (pointer: coarse), (forced-colors: active)"
const localizedCopy = (bg, en) => document.documentElement.lang.toLowerCase().startsWith("en") ? en : bg

export default class extends Controller {
  connect() {
    this.widgets = new Map()
    this.counter = 0
    this.typeahead = ""
    this.typeaheadTimer = null
    this.nativePickerQuery = window.matchMedia(NATIVE_PICKER_QUERY)
    this.handleModeChange = () => this.applyMode()
    this.handleOutsidePointer = (event) => this.closeOutside(event)
    this.handleResize = () => this.closeAll()
    this.handleScroll = (event) => {
      if (!event.target.closest?.(".select-menu__options")) this.closeAll()
    }
    this.handleMutations = (mutations) => this.refreshFromMutations(mutations)

    this.nativePickerQuery.addEventListener("change", this.handleModeChange)
    document.addEventListener("pointerdown", this.handleOutsidePointer)
    window.addEventListener("resize", this.handleResize)
    window.addEventListener("scroll", this.handleScroll, true)

    this.observer = new MutationObserver(this.handleMutations)
    this.observer.observe(this.element, { childList: true, subtree: true, attributes: true, attributeFilter: ["disabled"] })
    this.applyMode()
  }

  disconnect() {
    this.observer?.disconnect()
    this.nativePickerQuery?.removeEventListener("change", this.handleModeChange)
    document.removeEventListener("pointerdown", this.handleOutsidePointer)
    window.removeEventListener("resize", this.handleResize)
    window.removeEventListener("scroll", this.handleScroll, true)
    window.clearTimeout(this.typeaheadTimer)
    this.teardownAll()
  }

  applyMode() {
    if (this.nativePickerQuery.matches) {
      this.teardownAll()
    } else {
      this.enhanceWithin(this.element)
    }
  }

  refreshFromMutations(mutations) {
    if (this.nativePickerQuery.matches) return

    mutations.forEach((mutation) => {
      mutation.addedNodes.forEach((node) => {
        if (node instanceof Element) this.enhanceWithin(node)
      })
    })

    this.widgets.forEach((widget, select) => {
      if (select.isConnected) {
        this.sync(widget)
      } else {
        this.teardown(widget)
      }
    })
  }

  enhanceWithin(root) {
    const selects = []
    if (root.matches?.("select:not([multiple])")) selects.push(root)
    root.querySelectorAll?.("select:not([multiple])").forEach((select) => selects.push(select))
    selects.forEach((select) => this.enhance(select))
  }

  enhance(select) {
    if (this.widgets.has(select)) return

    const id = `select-menu-${++this.counter}`
    const wrapper = document.createElement("div")
    const trigger = document.createElement("button")
    const value = document.createElement("span")
    const menu = document.createElement("div")
    const original = {
      ariaHidden: select.getAttribute("aria-hidden"),
      tabIndex: select.getAttribute("tabindex")
    }

    wrapper.className = "select-menu"
    select.before(wrapper)
    wrapper.append(select)

    select.classList.add("select-menu__native")
    select.setAttribute("aria-hidden", "true")
    select.tabIndex = -1

    trigger.type = "button"
    trigger.id = `${id}-trigger`
    trigger.className = "select-menu__trigger"
    trigger.setAttribute("aria-haspopup", "listbox")
    trigger.setAttribute("aria-expanded", "false")
    trigger.setAttribute("aria-controls", `${id}-options`)
    value.id = `${id}-value`
    value.className = "select-menu__value"
    trigger.append(value)
    wrapper.append(trigger)

    menu.id = `${id}-options`
    menu.className = "select-menu__options"
    menu.setAttribute("role", "listbox")
    menu.setAttribute("aria-labelledby", trigger.id)
    menu.tabIndex = -1
    menu.hidden = true
    document.body.append(menu)

    const labelHandlers = Array.from(select.labels || []).map((label, index) => {
      if (!label.id) label.id = `${id}-label-${index + 1}`
      const handler = (event) => {
        event.preventDefault()
        trigger.focus()
      }
      label.addEventListener("click", handler)
      return { label, handler }
    })
    const labelIds = labelHandlers.map(({ label }) => label.id)
    if (labelIds.length) {
      trigger.setAttribute("aria-labelledby", `${labelIds.join(" ")} ${value.id}`)
    } else {
      trigger.setAttribute("aria-label", select.getAttribute("aria-label") || localizedCopy("Избери опция", "Choose an option"))
    }

    const widget = { select, wrapper, trigger, value, menu, original, labelHandlers }
    widget.changeHandler = () => this.sync(widget)
    widget.invalidHandler = (event) => {
      event.preventDefault()
      trigger.focus()
    }
    widget.triggerClickHandler = () => this.toggle(widget)
    widget.triggerKeyHandler = (event) => this.handleTriggerKeydown(event, widget)
    widget.menuKeyHandler = (event) => this.handleMenuKeydown(event, widget)

    select.addEventListener("change", widget.changeHandler)
    select.addEventListener("input", widget.changeHandler)
    select.addEventListener("invalid", widget.invalidHandler)
    trigger.addEventListener("click", widget.triggerClickHandler)
    trigger.addEventListener("keydown", widget.triggerKeyHandler)
    menu.addEventListener("keydown", widget.menuKeyHandler)

    this.widgets.set(select, widget)
    this.sync(widget)
  }

  sync(widget) {
    const { select, trigger, value, menu } = widget
    const selected = select.options[select.selectedIndex] || select.options[0]

    const selectedText = selected?.text || localizedCopy("Избери опция", "Choose an option")
    if (value.textContent !== selectedText) value.textContent = selectedText
    if (trigger.disabled !== select.disabled) trigger.disabled = select.disabled
    trigger.classList.toggle("is-placeholder", !selected?.value)
    menu.replaceChildren(...Array.from(select.options).map((option, index) => this.optionElement(widget, option, index)))

    if (!menu.hidden) this.positionMenu(widget)
  }

  optionElement(widget, option, index) {
    const item = document.createElement("div")
    item.id = `${widget.menu.id}-option-${index}`
    item.className = "select-menu__option"
    item.setAttribute("role", "option")
    item.setAttribute("aria-selected", String(option.selected))
    item.setAttribute("aria-disabled", String(option.disabled))
    item.tabIndex = -1
    item.dataset.index = String(index)
    item.textContent = option.text
    if (!option.value) item.classList.add("is-placeholder")
    item.addEventListener("click", () => this.choose(widget, index))
    item.addEventListener("pointermove", () => {
      if (!option.disabled && document.activeElement !== item) item.focus({ preventScroll: true })
    })
    return item
  }

  toggle(widget) {
    widget.menu.hidden ? this.open(widget) : this.close(widget, true)
  }

  open(widget, preferredIndex = widget.select.selectedIndex) {
    if (widget.trigger.disabled) return

    this.closeAll(widget)
    this.sync(widget)
    widget.menu.hidden = false
    widget.trigger.setAttribute("aria-expanded", "true")
    widget.wrapper.classList.add("is-open")
    this.positionMenu(widget)
    this.focusOption(widget, preferredIndex)
  }

  close(widget, restoreFocus = false) {
    if (widget.menu.hidden) return

    widget.menu.hidden = true
    widget.trigger.setAttribute("aria-expanded", "false")
    widget.wrapper.classList.remove("is-open")
    widget.menu.removeAttribute("aria-activedescendant")
    if (restoreFocus) widget.trigger.focus()
  }

  closeAll(except = null) {
    this.widgets.forEach((widget) => {
      if (widget !== except) this.close(widget)
    })
  }

  closeOutside(event) {
    this.widgets.forEach((widget) => {
      if (!widget.wrapper.contains(event.target) && !widget.menu.contains(event.target)) this.close(widget)
    })
  }

  positionMenu(widget) {
    const triggerRect = widget.trigger.getBoundingClientRect()
    const menu = widget.menu
    const gutter = 8
    const gap = 6
    const width = Math.max(triggerRect.width, 180)

    menu.style.width = `${width}px`
    menu.style.left = `${Math.min(Math.max(gutter, triggerRect.left), window.innerWidth - width - gutter)}px`
    menu.style.fontFamily = getComputedStyle(widget.trigger).fontFamily
    menu.style.fontSize = getComputedStyle(widget.trigger).fontSize

    const menuHeight = Math.min(menu.scrollHeight, 280)
    const spaceBelow = window.innerHeight - triggerRect.bottom - gutter
    const spaceAbove = triggerRect.top - gutter
    const openAbove = spaceBelow < menuHeight + gap && spaceAbove > spaceBelow
    const top = openAbove ? triggerRect.top - menuHeight - gap : triggerRect.bottom + gap

    menu.classList.toggle("is-above", openAbove)
    menu.style.top = `${Math.max(gutter, Math.min(top, window.innerHeight - menuHeight - gutter))}px`
  }

  handleTriggerKeydown(event, widget) {
    const { key } = event
    if (["Enter", " ", "ArrowDown", "ArrowUp", "Home", "End"].includes(key)) event.preventDefault()

    if (["Enter", " ", "ArrowDown"].includes(key)) this.open(widget)
    if (key === "ArrowUp") this.open(widget, widget.select.options.length - 1)
    if (key === "Home") this.open(widget, 0)
    if (key === "End") this.open(widget, widget.select.options.length - 1)
    if (key === "Escape") this.close(widget)
  }

  handleMenuKeydown(event, widget) {
    const options = this.enabledOptions(widget)
    const current = options.indexOf(document.activeElement)

    if (event.key === "ArrowDown") {
      event.preventDefault()
      options[(current + 1) % options.length]?.focus()
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      options[(current - 1 + options.length) % options.length]?.focus()
    } else if (event.key === "Home") {
      event.preventDefault()
      options[0]?.focus()
    } else if (event.key === "End") {
      event.preventDefault()
      options.at(-1)?.focus()
    } else if (["Enter", " "].includes(event.key)) {
      event.preventDefault()
      const index = Number(document.activeElement?.dataset.index)
      if (Number.isInteger(index)) this.choose(widget, index)
    } else if (event.key === "Escape") {
      event.preventDefault()
      this.close(widget, true)
    } else if (event.key === "Tab") {
      event.preventDefault()
      this.close(widget)
      this.focusAdjacentTo(widget.trigger, event.shiftKey)
    } else if (event.key.length === 1 && !event.ctrlKey && !event.metaKey && !event.altKey) {
      this.focusByTypeahead(event.key, widget)
    }
  }

  focusOption(widget, preferredIndex) {
    const preferred = widget.menu.querySelector(`[data-index="${preferredIndex}"]:not([aria-disabled="true"])`)
    const option = preferred || this.enabledOptions(widget)[0]
    option?.focus({ preventScroll: true })
    option?.scrollIntoView({ block: "nearest" })
    if (option) widget.menu.setAttribute("aria-activedescendant", option.id)
  }

  focusByTypeahead(character, widget) {
    window.clearTimeout(this.typeaheadTimer)
    this.typeahead += character.toLocaleLowerCase("bg")
    const match = this.enabledOptions(widget).find((option) => option.textContent.trim().toLocaleLowerCase("bg").startsWith(this.typeahead))
    match?.focus()
    this.typeaheadTimer = window.setTimeout(() => { this.typeahead = "" }, 500)
  }

  enabledOptions(widget) {
    return Array.from(widget.menu.querySelectorAll('.select-menu__option:not([aria-disabled="true"])'))
  }

  focusAdjacentTo(trigger, backwards) {
    const candidates = Array.from(document.querySelectorAll('a[href], button:not([disabled]), input:not([disabled]):not([type="hidden"]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'))
      .filter((element) => !element.closest(".select-menu__options") && !element.classList.contains("select-menu__native") && element.getClientRects().length)
    const current = candidates.indexOf(trigger)
    candidates[current + (backwards ? -1 : 1)]?.focus()
  }

  choose(widget, index) {
    const option = widget.select.options[index]
    if (!option || option.disabled) return

    widget.select.selectedIndex = index
    this.sync(widget)
    this.close(widget, true)
    widget.select.dispatchEvent(new Event("input", { bubbles: true }))
    widget.select.dispatchEvent(new Event("change", { bubbles: true }))
  }

  teardownAll() {
    Array.from(this.widgets.values()).forEach((widget) => this.teardown(widget))
  }

  teardown(widget) {
    const { select, wrapper, trigger, menu, original, labelHandlers } = widget
    select.removeEventListener("change", widget.changeHandler)
    select.removeEventListener("input", widget.changeHandler)
    select.removeEventListener("invalid", widget.invalidHandler)
    trigger.removeEventListener("click", widget.triggerClickHandler)
    trigger.removeEventListener("keydown", widget.triggerKeyHandler)
    menu.removeEventListener("keydown", widget.menuKeyHandler)
    labelHandlers.forEach(({ label, handler }) => label.removeEventListener("click", handler))

    select.classList.remove("select-menu__native")
    if (original.ariaHidden === null) select.removeAttribute("aria-hidden")
    else select.setAttribute("aria-hidden", original.ariaHidden)
    if (original.tabIndex === null) select.removeAttribute("tabindex")
    else select.setAttribute("tabindex", original.tabIndex)

    if (wrapper.isConnected) {
      wrapper.before(select)
      wrapper.remove()
    }
    menu.remove()
    this.widgets.delete(select)
  }
}
