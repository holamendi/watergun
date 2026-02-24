class Toast
  def self.append_to_user(user, message, type: :notice, link_text: nil, link_url: nil)
    Turbo::StreamsChannel.broadcast_append_to(
      [user, :toasts],
      target: "toasts",
      partial: "shared/toast",
      locals: {message:, type:, title: nil, link_text:, link_url:}
    )
  end
end
