class Toast
  def self.append_to_user(user, message, type: :notice)
    Turbo::StreamsChannel.broadcast_append_to(
      [user, :toasts],
      target: "toasts",
      partial: "shared/toast",
      locals: {message:, type:, title: nil}
    )
  end
end
