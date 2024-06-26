import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static values = { appId: Number, jid: String};

  connect() {
    console.log("Connected to AppLogsController", this.appIdValue, this.jidValue);

    this.channel = createConsumer().subscriptions.create(
      { channel: "LogStreamChannel", app_id: this.appIdValue, jid: this.jidValue},
      { connected: this._cableConnected.bind(this),
        disconnected: this._cableDisconnected.bind(this),
        received: this._cableReceived.bind(this)
      }
    );
  }

  disconnect() {
    this.channel.unsubscribe();
  }

  _cableConnected() {
    // Called when the subscription is ready for use on the server
    console.log("Cable connected")
  }

  _cableDisconnected() {
    // Called when the subscription has been terminated by the server
    console.log("Disconnected from the chat channel")
  }

  _cableReceived(data) {
    // Called when there's incoming data on the websocket for this channel
    console.log("Received data from the chat channel", data)
  }

  sendMessage(event) {
    event.preventDefault()
    const input = event.target.querySelector("input[type='text']")
    this.channel.perform("speak", { message: input.value })
    input.value = ""
  }

}
