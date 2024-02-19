module Apps
  class ActionsController < BaseController
    before_action :authorize_action

    ALLOWED_ACTIONS = %w[
      deploy
      restart
    ].freeze

    def create
      @app.create_and_enqueue_action!(params[:action_type])
      redirect_to @app, notice: "Action enqueued successfully."
    end

    private

    def authorize_action
      return if ALLOWED_ACTIONS.include?(params[:action])

      flash.now[:error] = "Action not allowed"
    end
  end
end
