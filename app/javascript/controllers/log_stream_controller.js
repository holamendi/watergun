import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
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
    this.startLogStream();
    this.startPing();
  }

  disconnect() {
    this.stopLogStream();
    this.stopPing();
  }

  startLogStream() {
    fetch(this.urlValue, {
      method: "PATCH",
      headers: this.requestHeaders(),
      body: JSON.stringify({}),
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

  requestHeaders() {
    return {
      "Accept": "application/json",
      "Content-Type": "application/json",
      "X-CSRF-Token": this.crsfToken,
    };
  }
}
