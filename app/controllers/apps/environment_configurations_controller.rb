module Apps
  class EnvironmentConfigurationsController < ApplicationController
    before_action :set_app

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
      params.require(:environment_configuration).permit(:variables).tap do |param|
        param[:variables] = variables_string_to_hash(param[:variables])
      end
    end

    def variables_string_to_hash(variables_string)
      variables_string.split("\n").map do |line|
        key, value = line.split("=")
        [key, value&.strip || ""]
      end.to_h
    end

    def set_app
      @app = current_server.apps.kept.find(params[:app_id])
    end
  end
end
