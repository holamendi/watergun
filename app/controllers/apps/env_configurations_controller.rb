module Apps
  class EnvConfigurationsController < BaseController
    before_action :set_env_configuration

    def edit
    end

    def update
      if @env_configuration.update(env_configuration_params)
        ServerActions::UpdateAppEnv.perform_later!(@app) if @env_configuration.saved_change_to_variables?
        redirect_to edit_app_env_configuration_path(@app), notice: "Env configuration updated successfully."
      else
        render :edit
      end
    end

    private

    def set_env_configuration
      @env_configuration = @app.env_configuration
    end

    def env_configuration_params
      params.require(:env_configuration).permit(:variables)
    end
  end
end
