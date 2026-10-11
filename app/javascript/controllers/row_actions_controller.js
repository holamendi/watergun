import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger", "menu"]

  get items() { return [...this.menuTarget.querySelectorAll('[role="menuitem"]')].filter(item => !item.disabled) }
  get opened() { return this.triggerTarget.getAttribute("aria-expanded") === "true" }

  toggle() { this.opened ? this.close(true) : this.open() }

  open(last = false) {
    this.menuTarget.showPopover()
    this.triggerTarget.setAttribute("aria-expanded", "true")
    const rect = this.triggerTarget.getBoundingClientRect()
    const menu = this.menuTarget.getBoundingClientRect()
    this.menuTarget.style.left = `${Math.max(8, Math.min(rect.right - menu.width, innerWidth - menu.width - 8))}px`
    this.menuTarget.style.top = `${Math.max(8, Math.min(rect.bottom + 4, innerHeight - menu.height - 8))}px`
    const items = this.items
    ;(last ? items.at(-1) : items[0])?.focus()
  }

  close(restore = false) {
    if (!this.hasMenuTarget) return
    this.menuTarget.hidePopover()
    this.triggerTarget.setAttribute("aria-expanded", "false")
    if (restore === true && this.triggerTarget.isConnected) this.triggerTarget.focus()
  }

  outside(event) { if (this.opened && !this.element.contains(event.target)) this.close() }
  choose(event) {
    if (event.target.closest('[role="menuitem"]')) this.close(true)
  }

  keydown(event) {
    if (["ArrowDown", "ArrowUp", "Home", "End"].includes(event.key)) {
      event.preventDefault()
      if (!this.opened) return this.open(event.key === "ArrowUp" || event.key === "End")
      const items = this.items
      const index = items.indexOf(document.activeElement)
      const next = event.key === "Home" ? 0 : event.key === "End" ? items.length - 1 : (index + (event.key === "ArrowUp" ? -1 : 1) + items.length) % items.length
      items[next]?.focus()
    } else if (event.key === "Escape" && this.opened) {
      event.preventDefault()
      event.stopPropagation()
      this.close(true)
    } else if (event.key === "Tab") {
      this.close(true)
    } else if (event.key === " " && document.activeElement.matches('a[role="menuitem"]')) {
      event.preventDefault()
      document.activeElement.click()
    }
  }

  disconnect() { this.close() }
}
