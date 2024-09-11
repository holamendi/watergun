class App::Destroyer
  def initialize(app)
    @app = app
  end

  def destroy
    @app.discard
    ServerActions::DestroyApp.run_later!(@app)
  end
end
