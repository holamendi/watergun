class Projects::Services::RestartsController < Projects::Services::BaseController
  def create
    ServerAction::RestartApp.run_later!(current_service)
    Notification.stream_later_to(current_user, "#{current_service.name}: restart scheduled")
  end
end
