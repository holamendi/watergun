class App::DestroyApp
  def initialize(app)
    @app = app
  end

  def destroy
    ServerActions::DestroyApp.run_later!(@app.server, @app)
  end
end
