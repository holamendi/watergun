class App::SetAppBuilder
  def initialize(app:, builder:)
    @app = app
    @builder = builder
  end

  def save
    ServerAction::TargetValidation.app_context!(@app)
    @app.builder = @builder
    return false unless @app.valid?

    App.transaction do
      @app.save!
      ServerAction::Enqueue.call(action: "apps.set_builder", target: @app)
    end
    true
  end
end
