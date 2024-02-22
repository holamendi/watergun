module Apps
  class EnvironmentConfigurationsController < BaseController
    def edit
    end

    def update
      if @app.environment_configuration.update(environment_configuration_params)
        redirect_to edit_app_environment_configuration_path(@app), notice: "Environment configuration updated successfully."
      else
        render :edit
      end
    end

    private

    def environment_configuration_params
      params.require(:environment_configuration).permit(:variables)
    end
  end
end
