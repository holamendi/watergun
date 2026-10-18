class ServiceLink::CreateServiceLink
  attr_reader :service, :app, :env_variable, :service_link

  def initialize(service:, app:)
    @service = service
    @app = app
  end

  def save!
    ServerAction::Conflict.with_app_lock(@app) do |app|
      @env_variable = @app.env_variables.kept.lock.find_or_initialize_by(name: env_name)
      @env_variable.value = "temp"
      @env_variable.internal = true
      @env_variable.save!
      app.increment!(:env_generation)
      @service_link = ServiceLink.create!(service: @service, app: @app, env_variable: @env_variable)
      ServerAction::Enqueue.call(action: "services.link", target: @service_link)
    end

    true
  end

  private

  def env_name
    "INTERNAL_#{@service.dokku_id.underscore.upcase}_URL"
  end
end
