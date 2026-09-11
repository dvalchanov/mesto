import { Controller } from "@hotwired/stimulus"

const NATIVE_PICKER_QUERY = "(max-width: 760px), (pointer: coarse), (forced-colors: active)"

export default class extends Controller {
  connect() {
    this.listId = this.element.getAttribute("list")
    this.list = document.getElementById(this.listId)
    if (!this.list) return

    this.pickerQuery = window.matchMedia(NATIVE_PICKER_QUERY)
    this.handleModeChange = () => this.applyMode()
    this.handleFocus = () => this.open()
    this.handleInput = () => {
      if (document.activeElement === this.element) this.open(this.element.value)
      else this.close()
    }
    this.handleKeydown = (event) => this.keydown(event)
    this.handleMenuKeydown = (event) => this.menuKeydown(event)
    this.handleOutsidePointer = (event) => {
      if (event.target !== this.element && !this.menu?.contains(event.target)) this.close()
    }
    this.handleResize = () => this.close()
    this.handleScroll = (event) => {
      if (event.isTrusted && performance.now() - this.openedAt < 100) return
      if (!event.target.closest?.(".combobox-options")) this.close()
    }

    this.pickerQuery.addEventListener("change", this.handleModeChange)
    this.applyMode()
  }

  disconnect() {
    this.pickerQuery?.removeEventListener("change", this.handleModeChange)
    this.disableCustomMenu()
  }

  applyMode() {
    if (this.pickerQuery.matches) this.disableCustomMenu()
    else this.enableCustomMenu()
  }

  enableCustomMenu() {
    if (this.customMenuEnabled) return

    this.customMenuEnabled = true
    this.element.removeAttribute("list")
    this.element.classList.add("combobox-input")
    this.element.setAttribute("role", "combobox")
    this.element.setAttribute("aria-autocomplete", "list")
    this.element.setAttribute("aria-expanded", "false")

    this.menu = document.createElement("div")
    this.menu.id = `${this.element.id}-suggestions`
    this.menu.className = "select-menu__options combobox-options"
    this.menu.setAttribute("role", "listbox")
    this.menu.setAttribute("aria-labelledby", this.element.id)
    this.menu.hidden = true
    document.body.append(this.menu)
    this.element.setAttribute("aria-controls", this.menu.id)

    this.element.addEventListener("focus", this.handleFocus)
    this.element.addEventListener("click", this.handleFocus)
    this.element.addEventListener("input", this.handleInput)
    this.element.addEventListener("keydown", this.handleKeydown)
    this.menu.addEventListener("keydown", this.handleMenuKeydown)
    document.addEventListener("pointerdown", this.handleOutsidePointer)
    window.addEventListener("resize", this.handleResize)
    window.addEventListener("scroll", this.handleScroll, true)
  }

  disableCustomMenu() {
    if (!this.customMenuEnabled) return

    this.element.removeEventListener("focus", this.handleFocus)
    this.element.removeEventListener("click", this.handleFocus)
    this.element.removeEventListener("input", this.handleInput)
    this.element.removeEventListener("keydown", this.handleKeydown)
    this.menu?.removeEventListener("keydown", this.handleMenuKeydown)
    document.removeEventListener("pointerdown", this.handleOutsidePointer)
    window.removeEventListener("resize", this.handleResize)
    window.removeEventListener("scroll", this.handleScroll, true)
    this.menu?.remove()

    this.element.setAttribute("list", this.listId)
    this.element.classList.remove("combobox-input")
    this.element.removeAttribute("role")
    this.element.removeAttribute("aria-autocomplete")
    this.element.removeAttribute("aria-expanded")
    this.element.removeAttribute("aria-controls")
    this.element.removeAttribute("aria-activedescendant")
    this.menu = null
    this.customMenuEnabled = false
  }

  open(query = "") {
    if (!this.customMenuEnabled) return

    const normalizedQuery = query.trim().toLocaleLowerCase("bg")
    const choices = Array.from(this.list.options)
      .map((option) => option.value)
      .filter((value) => !normalizedQuery || value.toLocaleLowerCase("bg").includes(normalizedQuery))

    this.menu.replaceChildren(...choices.map((value, index) => this.option(value, index)))
    if (!choices.length) return this.close()

    this.openedAt = performance.now()
    this.menu.hidden = false
    this.element.setAttribute("aria-expanded", "true")
    this.positionMenu()
  }

  option(value, index) {
    const item = document.createElement("div")
    item.id = `${this.menu.id}-option-${index}`
    item.className = "select-menu__option"
    item.setAttribute("role", "option")
    item.setAttribute("aria-selected", String(value === this.element.value))
    item.tabIndex = -1
    item.textContent = value
    item.addEventListener("pointerdown", (event) => {
      event.preventDefault()
      this.choose(value)
    })
    return item
  }

  choose(value) {
    this.element.value = value
    this.element.dispatchEvent(new Event("input", { bubbles: true }))
    this.element.dispatchEvent(new Event("change", { bubbles: true }))
    this.element.focus()
    this.close()
  }

  close() {
    if (!this.menu || this.menu.hidden) return

    this.menu.hidden = true
    this.element.setAttribute("aria-expanded", "false")
    this.element.removeAttribute("aria-activedescendant")
  }

  keydown(event) {
    if (event.key === "ArrowDown") {
      event.preventDefault()
      if (this.menu.hidden) this.open()
      this.focusOption(0)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      if (this.menu.hidden) this.open()
      this.focusOption(-1)
    } else if (event.key === "Escape") {
      this.close()
    } else if (event.key === "Tab") {
      event.preventDefault()
      this.close()
      this.focusAdjacent(event.shiftKey)
    }
  }

  menuKeydown(event) {
    const options = Array.from(this.menu.querySelectorAll(".select-menu__option"))
    const current = options.indexOf(document.activeElement)

    if (event.key === "ArrowDown") {
      event.preventDefault()
      options[(current + 1) % options.length]?.focus()
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      options[(current - 1 + options.length) % options.length]?.focus()
    } else if (["Enter", " "].includes(event.key)) {
      event.preventDefault()
      if (document.activeElement?.classList.contains("select-menu__option")) this.choose(document.activeElement.textContent)
    } else if (event.key === "Escape") {
      event.preventDefault()
      this.close()
      this.element.focus()
    } else if (event.key === "Tab") {
      this.close()
    }
  }

  focusOption(index) {
    const options = Array.from(this.menu.querySelectorAll(".select-menu__option"))
    const option = index < 0 ? options.at(-1) : options[index]
    option?.focus({ preventScroll: true })
    if (option) this.element.setAttribute("aria-activedescendant", option.id)
  }

  focusAdjacent(backwards) {
    const candidates = Array.from(document.querySelectorAll('a[href], button:not([disabled]), input:not([disabled]):not([type="hidden"]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'))
      .filter((element) => !element.closest(".select-menu__options") && element.getClientRects().length)
    const current = candidates.indexOf(this.element)
    candidates[current + (backwards ? -1 : 1)]?.focus()
  }

  positionMenu() {
    const rect = this.element.getBoundingClientRect()
    const gutter = 8
    const gap = 6
    const width = Math.max(rect.width, 180)
    const menuHeight = Math.min(this.menu.scrollHeight, 280)
    const spaceBelow = window.innerHeight - rect.bottom - gutter
    const spaceAbove = rect.top - gutter
    const openAbove = spaceBelow < menuHeight + gap && spaceAbove > spaceBelow
    const top = openAbove ? rect.top - menuHeight - gap : rect.bottom + gap

    this.menu.style.width = `${width}px`
    this.menu.style.left = `${Math.min(Math.max(gutter, rect.left), window.innerWidth - width - gutter)}px`
    this.menu.style.top = `${Math.max(gutter, Math.min(top, window.innerHeight - menuHeight - gutter))}px`
    this.menu.style.fontFamily = getComputedStyle(this.element).fontFamily
    this.menu.style.fontSize = getComputedStyle(this.element).fontSize
  }
}
