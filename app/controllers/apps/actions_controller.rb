module Apps
  class ActionsController < ApplicationController
    before_action :set_app, :authorize_action

    ALLOWED_ACTIONS = %w[
      deploy
      restart
    ].freeze

    def create
      @app.enqueue_action!(params[:action_type])
      redirect_to app_path(@app), notice: "Action enqueued successfully."
    end

    private

    def set_app
      @app = current_server.apps.kept.find(params[:app_id])
    end

    def authorize_action
      return if ALLOWED_ACTIONS.include?(params[:action])

      flash.now[:error] = "Action not allowed"
    end
  end
end
