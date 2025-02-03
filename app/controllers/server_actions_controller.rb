class ServerActionsController < ApplicationController
  def index
    @server_actions = Current.server.actions.recent.includes(:user).limit(200)
  end

  def update
    @server_action = Current.server.actions.find(params[:id])
  end

  def logs
    @server_action = Current.server.actions.find(params[:id])

    log = if @server_action.log.present?
      @server_action.log.to_s
    elsif @server_action.failure_message.present?
      @server_action.failure_message
    else
      "No logs available"
    end

    render plain: log
  end
end
