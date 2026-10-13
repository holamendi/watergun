class Projects::Services::RestartsController < Projects::Services::BaseController
  def create
    ServerAction::Enqueue.call(action: ServerActions::RestartService, target: @service)
    render turbo_stream: stream_toast("Restart scheduled")
  end
end
