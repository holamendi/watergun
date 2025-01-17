class App::DestroyApp
  def initialize(app)
    @app = app
  end

  def call
    @app.discard
    ServerActions::DestroyApp.run_later!(app.server, @app)
  end
end
