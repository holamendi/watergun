import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "overlay", "mobileSidebar"]

  connect() {
    const stored = localStorage.getItem("sidebar-expanded")
    this.expanded = stored === null ? true : stored === "true"
    // Sync state in case it changed
    this.updateDesktopState()
  }

  toggle() {
    this.expanded = !this.expanded
    localStorage.setItem("sidebar-expanded", this.expanded)
    this.updateDesktopState()
  }

  openMobile() {
    if (this.hasMobileSidebarTarget) {
      this.mobileSidebarTarget.classList.remove("-translate-x-full")
      this.overlayTarget.classList.remove("hidden")
    }
  }

  closeMobile() {
    if (this.hasMobileSidebarTarget) {
      this.mobileSidebarTarget.classList.add("-translate-x-full")
      this.overlayTarget.classList.add("hidden")
    }
  }

  updateDesktopState() {
    // Toggle class on html element for CSS-based hiding
    if (this.expanded) {
      document.documentElement.classList.remove("sidebar-collapsed")
    } else {
      document.documentElement.classList.add("sidebar-collapsed")
    }

    // Also toggle the panel directly for immediate feedback
    if (this.hasPanelTarget) {
      if (this.expanded) {
        this.panelTarget.classList.remove("hidden")
      } else {
        this.panelTarget.classList.add("hidden")
      }
    }
  }
}
