class Projects::Apps::RestartsController < Projects::Apps::BaseController
  def create
    ServerAction::Enqueue.call(action: ServerActions::RestartApp, target: @app)
    render turbo_stream: stream_toast("Restart scheduled")
  end
end
