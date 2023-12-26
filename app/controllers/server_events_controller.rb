class ServerEventsController < ApplicationController
  before_action :set_server, only: %i[show edit update destroy]

  def logs
    @server_event = current_server.server_events.find(params[:id])
  end
end
