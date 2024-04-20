class ServerActionsController < ApplicationController
  def index
    @server_actions = current_server.server_actions.order(created_at: :desc)
  end

  def logs
    @action = current_server.server_actions.find(params[:id])

    render plain: @action.action_log.text_output
  end
end
