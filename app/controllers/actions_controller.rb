class ActionsController < ApplicationController
  def index
    @actions = current_server.actions.order(created_at: :desc)
  end

  def logs
    @action = current_server.actions.find(params[:id])

    render plain: @action.action_log.text_output
  end
end
