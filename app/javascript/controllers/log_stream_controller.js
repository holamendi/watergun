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

  }

  _cableDisconnected() {

  }

  _cableReceived(data) {
    console.log(data)
  }
}
