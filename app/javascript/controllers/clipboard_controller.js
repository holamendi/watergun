import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source"]

  copy() {
    const text = this.sourceTarget.value
    navigator.clipboard.writeText(text).then(() => {
      console.log("Copied to clipboard:", text)
      // Add visual feedback here (e.g., temporarily change button text or show a tooltip)
    }).catch(err => {
      console.error('Failed to copy: ', err)
    })
  }
}
