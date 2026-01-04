import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  preview(event) {
    const selectedTheme = event.target.value
    this.applyTheme(selectedTheme)
  }

  applyTheme(theme) {
    document.documentElement.setAttribute("data-theme", theme)
    localStorage.setItem("watergun-theme", theme)
  }

  connect() {
    const storedTheme = localStorage.getItem("watergun-theme")
    if (storedTheme) {
      this.applyTheme(storedTheme)
    }
  }
}
