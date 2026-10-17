class App::SetAppBuilder
  def initialize(app:, builder:)
    @app = app
    @builder = builder
  end

  def save
    ServerAction::TargetValidation.app_context!(@app)
    @app.builder = @builder
    return false unless @app.valid?

    ServerAction::Conflict.with_app_lock(@app) do
      @app.save!
      ServerAction::Enqueue.call(action: "apps.set_builder", target: @app)
    end
    true
  end
end
