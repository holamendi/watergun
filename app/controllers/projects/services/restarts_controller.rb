class Projects::Services::RestartsController < Projects::Services::BaseController
  def create
    ServerActions::RestartApp.run_later!(@service)
    Notification.stream_later_to(Current.user, "#{@service.name}: restart scheduled")
  end
end
