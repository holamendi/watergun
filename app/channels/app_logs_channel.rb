class AppLogsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "stream_#{params[:jid]}"
  end

  def unsubscribed
    Rails.cache.delete("stream_#{params[:jid]}")
  end
end
