module Projects
  module Apps
    class BuildersController < BaseController
      def update
        if current_app.update(app_params)
          ServerAction::UpdateBuilder.run_later!(current_app)
          render turbo_stream: notify("Builder updated")
        else
          turbo_stream_errors
        end
      end

      private

      def app_params
        params.require(:app).permit(:builder)
      end

      def turbo_stream_errors
        render turbo_stream: turbo_stream.replace(
          "builder_form",
          partial: "projects/apps/builders/form",
          locals: {
            app: current_app
          }
        )
      end
    end
  end
end
