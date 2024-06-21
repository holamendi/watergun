module ServerActions
  class LinkService < ServerAction
    SLUG = "services.link"

    actionable ServiceLink

    store_attribute :payload, :dokku_app_id, :string
    store_attribute :payload, :dokku_service_id, :string
    store_attribute :payload, :service_type, :string

    validates :dokku_app_id, presence: true
    validates :dokku_service_id, presence: true
    validates :service_type, presence: true

    delegate :app, :service, to: :service_link

    before_validation on: :create do
      self.dokku_app_id ||= app.dokku_id
      self.dokku_service_id ||= service.dokku_id
      self.service_type ||= service.service_type
    end

    def concurrency_key
      service
    end

    def perform
      link_dokku_service!
    rescue Ssh::CommandExecutionError
      service_link.error!
      raise
    else
      service_link.active!
    end

    private

    def link_dokku_service!
      dokku_command_class.call!(ssh, service: dokku_service_id, app: dokku_app_id)
    end

    def dokku_command_class
      "Dokku::#{service_type.camelcase}::Link".constantize
    end
  end
end
