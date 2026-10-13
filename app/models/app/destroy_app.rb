class App::DestroyApp
  def initialize(app)
    @app = app
  end

  def destroy
    ServerAction::Enqueue.call(action: ServerActions::DestroyApp, target: @app)
  end
end
