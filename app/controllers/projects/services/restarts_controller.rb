class Projects::Services::RestartsController < Projects::Services::BaseController
  def create
    ServerActions::RestartService.run_later!(@service.server, @service)
    render turbo_stream: stream_toast("Restart scheduled")
  end
end
