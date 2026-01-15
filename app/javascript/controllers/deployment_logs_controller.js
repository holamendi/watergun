import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["container", "scrollAnchor", "placeholder"];

  connect() {
    this.autoScroll = true;
    this.observeLogs();
    this.observeScroll();
  }

  disconnect() {
    this.disconnectLogs();
    this.disconnectScroll();
  }

  observeLogs() {
    this.logObserver = new MutationObserver(() => {
      // Remove placeholder on first log content
      if (this.hasPlaceholderTarget) {
        this.placeholderTarget.remove();
      }

      if (this.autoScroll) {
        this.scrollToBottom();
      }
    });

    this.logObserver.observe(this.element, {
      childList: true,
      subtree: true,
    });
  }

  disconnectLogs() {
    if (this.logObserver) {
      this.logObserver.disconnect();
    }
  }

  observeScroll() {
    this.element.addEventListener("scroll", this.handleScroll);
  }

  disconnectScroll() {
    this.element.removeEventListener("scroll", this.handleScroll);
  }

  handleScroll = () => {
    const { scrollTop, scrollHeight, clientHeight } = this.element;
    const isAtBottom = scrollHeight - scrollTop - clientHeight < 50;

    this.autoScroll = isAtBottom;
  };

  scrollToBottom() {
    if (this.hasScrollAnchorTarget) {
      this.scrollAnchorTarget.scrollIntoView({ behavior: "smooth" });
    } else {
      this.element.scrollTop = this.element.scrollHeight;
    }
  }
}
