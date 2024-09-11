module Projects
  module Apps
    class RestartsController < BaseController
      def create
        ServerActions::RestartApp.run_later!(@app)
        Notification.stream_later_to(Current.user, "#{@app.name}: restart scheduled")
      end
    end
  end
end
