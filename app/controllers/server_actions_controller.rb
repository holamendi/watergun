class ServerActionsController < ApplicationController
  def index
    @server_actions = Current.server.actions.recent.includes(:user).limit(200)
  end

  def update
    @server_action = Current.server.actions.find(params[:id])
  end

  def logs
    @server_action = Current.server.actions.find(params[:id])
    render plain: @server_action.log.to_s
  end
end
