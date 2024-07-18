class ServerActionsController < ApplicationController
  def index
    @server_actions = current_server.actions.recent.includes(:user).limit(50)
  end

  def update
    @server_action = current_server.actions.find(params[:id])
  end

  def logs
    @server_action = current_server.actions.find(params[:id])
    render plain: @server_action.log.to_s
  end
end
