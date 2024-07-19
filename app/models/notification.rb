class Notification
  def self.stream_later_to(user, message, type: :notice)
    Turbo::StreamsChannel.broadcast_prepend_later_to([user, :toasts],
      target: "toasts",
      partial: "shared/toast",
      locals: {message:, type:})
  end
end
