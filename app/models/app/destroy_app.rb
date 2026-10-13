class App::DestroyApp
  def initialize(app)
    @app = app
  end

  def destroy
    ServerAction::Enqueue.call(action: "apps.destroy", target: @app)
  end
end
