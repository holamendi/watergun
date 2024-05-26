module ServerActions
  class UnlinkService < ServerAction
    ACTION_CODE = "services.unlink"

    alias_method :service_link, :actionable

    store_attribute :payload, :dokku_app_id, :string
    store_attribute :payload, :dokku_service_id, :string
    store_attribute :payload, :service_type, :string

    validates :dokku_app_id, :dokku_service_id, :service_type, presence: true

    before_validation on: :create do
      self.dokku_app_id ||= app.dokku_id
      self.dokku_service_id ||= service.dokku_id
      self.service_type ||= service.service_type
    end

    delegate :app, :service, to: :service_link

    def concurrency_key
      service
    end

    def perform
      result = dokku_command_class.call(ssh, service: dokku_service_id, app: dokku_app_id)
      service_link.unlinked! if result.success?
    end

    private

    def dokku_command_class
      "Dokku::#{service_type.camelcase}::Unlink".constantize
    end
  end
end
