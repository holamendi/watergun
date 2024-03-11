class ActionsController < ApplicationController
  def logs
    @action = current_server.actions.find(params[:id])

    render plain: @action.action_log.text_output
  end
end
