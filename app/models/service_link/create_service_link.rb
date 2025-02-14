class ServiceLink::CreateServiceLink
  attr_reader :service, :app, :env_variable, :service_link

  def initialize(service:, app:)
    @service = service
    @app = app
    @env_name = "INTERNAL_#{service.dokku_id.underscore.upcase}_URL"
  end

  def save
    @env_variable = @app.env_variables.kept.find_or_initialize_by(name: @env_name)
    @env_variable.assign_attributes(value: "temp", internal: true)

    ApplicationRecord.transaction do
      @env_variable.save!
      @service_link = ServiceLink.create!(
        service: @service,
        app: @app,
        env_variable: @env_variable
      )
    end

    ServerActions::LinkService.run_later!(@service.server, @service_link)
    true
  end
end
