module ServerActions
  class RestartService < ServerAction
    SLUG = "services.restart"

    alias_method :service, :actionable

    store_attribute :payload, :dokku_service_id, :string
    store_attribute :payload, :service_type, :string

    validates :dokku_service_id, presence: true

    before_validation on: :create do
      self.service_type ||= service.service_type
      self.dokku_service_id ||= service.dokku_id
    end

    def perform
      restart_dokku_service!
    end

    private

    def restart_dokku_service!
      dokku_command_class.call!(ssh, service: dokku_service_id)
    end

    def dokku_command_class
      "Dokku::#{service_type.camelcase}::Restart".constantize
    end
  end
end
