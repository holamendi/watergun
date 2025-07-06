class Projects::Apps::RestartsController < Projects::Apps::BaseController
  def create
    ServerActions::RestartApp.run_later!(@app)
    render turbo_stream: stream_toast("Restart scheduled")
  end
end
