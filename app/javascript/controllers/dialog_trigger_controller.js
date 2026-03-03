import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    target: String
  }

  open() {
    const dialog = document.getElementById(this.targetValue)
    dialog?.showModal()
  }
}
