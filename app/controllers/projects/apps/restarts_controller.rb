module Projects
  module Apps
    class RestartsController < BaseController
      def create
        ServerAction::RestartApp.run_later!(current_app)
        turbo_stream_toast("#{current_app.name}: restart scheduled")
      end
    end
  end
end
