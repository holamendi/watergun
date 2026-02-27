import { Controller } from "@hotwired/stimulus"

// Generic controller for revealing/masking secret values.
// Usage:
//   <div data-controller="secret-field" data-secret-field-value-value="the_secret">
//     <span data-secret-field-target="display">••••••••</span>
//     <button data-action="secret-field#toggle">
//       <svg data-secret-field-target="iconHidden">eye</svg>
//       <svg data-secret-field-target="iconRevealed" class="hidden">eye-off</svg>
//     </button>
//   </div>
export default class extends Controller {
  static targets = ["display", "iconHidden", "iconRevealed"]
  static values = { value: String, mask: { type: String, default: "••••••••" } }

  toggle() {
    if (this.element.dataset.revealed === "true") {
      this.hide()
    } else {
      this.reveal()
    }
  }

  reveal() {
    this.displayTarget.textContent = this.valueValue
    this.element.dataset.revealed = "true"
    if (this.hasIconHiddenTarget) this.iconHiddenTarget.classList.add("hidden")
    if (this.hasIconRevealedTarget) this.iconRevealedTarget.classList.remove("hidden")
  }

  hide() {
    this.displayTarget.textContent = this.maskValue
    this.element.dataset.revealed = "false"
    if (this.hasIconHiddenTarget) this.iconHiddenTarget.classList.remove("hidden")
    if (this.hasIconRevealedTarget) this.iconRevealedTarget.classList.add("hidden")
  }
}
