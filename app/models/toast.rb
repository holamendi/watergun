class Toast
  def self.append_to_user(user, message, type: :notice)
    Turbo::StreamsChannel.broadcast_append_to(
      [user, :toasts],
      target: "toasts",
      html: ApplicationController.render(ToastComponent.new(message:, type:), layout: false)
    )
  end
end
