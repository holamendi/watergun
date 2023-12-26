class ServerEventsController < ApplicationController
  def logs
    @server_event = current_server.server_events.find(params[:id])
  end
end
