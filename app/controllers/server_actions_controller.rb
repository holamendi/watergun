class ServerActionsController < ApplicationController
  def index
    @server_actions = Current.server.actions.recent.includes(:user).limit(200)
  end

  def retry
    @server_action = Current.server.actions.find(params[:id])
    @server_action.run_later
    render json: {status: :ok}
  end

  def logs
    @server_action = Current.server.actions.find(params[:id])

    log = if @server_action.log.present?
      JSON.pretty_generate(@server_action.log.ssh_commands)
    elsif @server_action.failure_message.present?
      @server_action.failure_message
    else
      "No logs available"
    end

    render json: log
  end
end
