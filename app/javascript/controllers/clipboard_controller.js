import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "icon"]

  copy() {
    navigator.clipboard.writeText(this.sourceTarget.value).then(() => {
      this.showCopiedFeedback()
    })
  }

  showCopiedFeedback() {
    const originalIcon = this.iconTarget.innerHTML
    this.iconTarget.innerHTML = `
      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
        <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
      </svg>
    `
    setTimeout(() => {
      this.iconTarget.innerHTML = originalIcon
    }, 2000)
  }
}
