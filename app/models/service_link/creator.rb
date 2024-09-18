class ServiceLink::Creator
  attr_reader :service, :app, :env_name, :env_variable, :service_link

  def initialize(service:, app:, env_name: nil)
    @service = service
    @app = app
    @env_name = env_name
  end

  def create
    ApplicationRecord.transaction do
      @env_variable = @app.env_variables.kept.find_or_initialize_by(name: @env_name)
      @env_variable.value = "temp"
      @env_variable.internal = true
      @env_variable.save!

      @service_link = ServiceLink.create!(service: @service, app: @app, env_variable: @env_variable)
    end

    ServerActions::LinkService.run_later!(@service_link)
  end
end
