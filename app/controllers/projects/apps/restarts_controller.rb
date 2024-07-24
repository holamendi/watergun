module Projects
  module Apps
    class RestartsController < BaseController
      def create
        ServerAction::RestartApp.run_later!(current_app)
        Notification.stream_later_to(current_user, "#{current_app.name}: restart scheduled")
      end
    end
  end
end
