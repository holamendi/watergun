module Dokku
  class AppLogStreamChannel < ApplicationCable::Channel
    def subscribed
      stream_from "stream_channel"
    end

    def unsubscribed
      Rails.cache.delete("stream_#{params["id"]}")
    end
  end
end
