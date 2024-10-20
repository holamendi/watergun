class Projects::Apps::RestartsController < Projects::Apps::BaseController
  def create
    ServerActions::RestartApp.run_later!(@app)
    render turbo_stream: append_toast("Restart scheduled")
  end
end
