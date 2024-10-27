module Projects
  module Apps
    class EnvVariablesController < BaseController
      before_action :set_env_variable, only: %i[show edit update destroy]

      def new
        @env_variable = @app.env_variables.new
      end

      def index
        @env_variables = @app.env_variables.kept.editable
          .includes(service_link: :service)
          .order(:name)
      end

      def create
        @env_variable = @app.env_variables.new(env_variable_params)

        if @env_variable.save
          ServerActions::UpdateEnv.run_later!(@app, set: @env_variable.to_h)
          redirect_to project_app_env_variables_path(@project, @app), notice: "Environment variable created successfully."
        else
          turbo_stream_errors
        end
      end

      def edit
      end

      def update
        if @env_variable.update(env_variable_params)
          ServerActions::UpdateEnv.run_later!(@app, set: @env_variable.to_h) if @env_variable.saved_change_to_value?
          redirect_to project_app_env_variable_path(@project, @app, @env_variable), notice: "Environment variable updated successfully."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @env_variable.discard!
        ServerActions::UpdateEnv.run_later!(@app, unset: [@env_variable.name])
        render turbo_stream: turbo_stream.remove(@env_variable)
      end

      private

      def set_env_variable
        @env_variable = @app.env_variables.kept.find(params[:id])
      end

      def env_variable_params
        params.require(:env_variable).permit(:name, :value)
      end

      def turbo_stream_errors
        render turbo_stream: turbo_stream.replace(
          @env_variable,
          partial: "projects/apps/env_variables/form",
          locals: {
            project: @project,
            app: @app,
            env_variable: @env_variable
          }
        )
      end
    end
  end
end
