class ServerActionsController < ApplicationController
  def index
    @pagy, @server_actions = pagy(Current.server.actions.recent.includes(:user), limit: 25)
  end

  def show
    @server_action = Current.server.actions.find(params[:id])
  end
end
