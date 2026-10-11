import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "icon", "status"]
  static values = { text: String }

  async copy(event) {
    event.preventDefault()
    const text = this.hasTextValue ? this.textValue : this.sourceTarget.value
    try {
      await navigator.clipboard.writeText(text)
      if (this.hasIconTarget) this.showCopiedIcon()
      if (this.hasStatusTarget) this.statusTarget.textContent = "Value copied."
    } catch {
      if (this.hasStatusTarget) this.statusTarget.textContent = "Copy failed. Try again or copy the revealed value."
    }
  }

  showCopiedIcon() {
    const originalIcon = this.iconTarget.innerHTML
    this.iconTarget.innerHTML = `
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" stroke-width="1.5" class="stroke-success w-4 h-4">
        <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
      </svg>
    `
    setTimeout(() => {
      this.iconTarget.innerHTML = originalIcon
    }, 1500)
  }
}
