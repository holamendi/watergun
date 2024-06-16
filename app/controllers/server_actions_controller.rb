class ServerActionsController < ApplicationController
  def index
    @server_actions = current_server.actions.recent.limit(20)
  end

  def logs
    @server_action = current_server.actions.find(params[:id])
    render plain: @server_action.log&.text_output
  end
end
