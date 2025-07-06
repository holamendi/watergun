class App::DestroyApp
  def initialize(app)
    @app = app
  end

  def destroy
    @app.discard
    ServerActions::DestroyApp.run_later!(@app.server, @app)
  end
end
