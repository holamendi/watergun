module Apps
  class EnvironmentConfigurationsController < BaseController
    before_action :set_environment_configuration

    def edit
    end

    def update
      if @environment_configuration.update(environment_configuration_params)
        schedule_update_env_action
        redirect_to edit_app_environment_configuration_path(@app), notice: "Environment configuration updated successfully."
      else
        render :edit
      end
    end

    private

    def set_environment_configuration
      @environment_configuration = @app.environment_configuration
    end

    def environment_configuration_params
      params.require(:environment_configuration).permit(:variables)
    end

    def schedule_update_env_action
      return unless @environment_configuration.saved_change_to_variables?

      @app.schedule_action!(
        Apps::UpdateEnv,
        app_dokku_id: @app.dokku_id,
        environment_variables: @environment_configuration.variables
      )
    end
  end
end
