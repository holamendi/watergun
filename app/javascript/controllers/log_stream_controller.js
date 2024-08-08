import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["overlay"];

  static values = {
    url: String,
    pingInterval: {
      type: Number,
      default: 1000,
    },
  };

  connect() {
    this.crsfToken = document
      .querySelector("meta[name='csrf-token']")
      .getAttribute("content");

    this.scrollObserver = new MutationObserver(() => {
      this.scrollToBottom()
    })

    this.scrollObserver.observe(this.element, {
      childList: true,
      subtree: true
    })

    this.overlayObserver = new MutationObserver(() => {
      this.overlayTarget.remove()
      this.overlayObserver.disconnect()
    })

    this.overlayObserver.observe(this.element, {
      childList: true,
      subtree: true
    })

    this.startLogStream();
    this.startPing();
  }

  disconnect() {
    this.stopLogStream();
    this.stopPing();

    if (this.scrollObserver) {
      this.scrollObserver.disconnect();
    }

    if (this.overlayObserver) {
      this.overlayObserver.disconnect();
    }
  }

  startLogStream() {
    fetch(this.urlValue, {
      method: "PATCH", headers: this.requestHeaders(), body: JSON.stringify({})
    });
  }

  startPing() {
    this.ping = setInterval(() => {
      fetch(this.urlValue, { method: "GET" });
    }, this.pingIntervalValue);
  }

  stopLogStream() {
    fetch(this.urlValue, {
      method: "DELETE",
      headers: this.requestHeaders(),
      body: JSON.stringify({}),
    });
  }

  stopPing() {
    clearInterval(this.ping);
  }

  scrollToBottom() {
    this.element.scrollTop = this.element.scrollHeight
  }

  requestHeaders() {
    return {
      "Accept": "application/json",
      "Content-Type": "application/json",
      "X-CSRF-Token": this.crsfToken,
    };
  }
}
