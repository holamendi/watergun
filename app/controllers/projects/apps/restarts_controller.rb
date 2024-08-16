module Projects
  module Apps
    class RestartsController < BaseController
      def create
        ServerAction::RestartApp.run_later!(@app)
        Notification.stream_later_to(Current.user, "#{@app.name}: restart scheduled")
      end
    end
  end
end
