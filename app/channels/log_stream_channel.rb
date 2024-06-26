class LogStreamChannel < ApplicationCable::Channel
  def subscribed
    stream_from "log_stream_#{params[:jid]}"
  end

  def unsubscribed
    app = App.find(params[:app_id])
    Servers::StopLogStreamJob.perform_later(app, params[:jid])
  end
end
