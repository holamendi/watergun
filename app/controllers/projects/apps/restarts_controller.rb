module Projects
  module Apps
    class RestartsController < BaseController
      def create
        ServerActions::RestartApp.perform_later!(current_app)
        redirect_to project_app_path(current_project, current_app), notice: "App restart scheduled successfully."
      end
    end
  end
end
