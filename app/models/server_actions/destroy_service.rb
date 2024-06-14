module ServerActions
  class DestroyService < ServerAction
    SLUG = "services.destroy"

    alias_method :service, :actionable

    store_attribute :payload, :dokku_service_id, :string
    store_attribute :payload, :service_type, :string

    validates :dokku_service_id, presence: true

    before_validation on: :create do
      self.service_type ||= service.service_type
      self.dokku_service_id ||= service.dokku_id
    end

    def perform
      destroy_dokku_service!
      service.status_destroyed!
    end

    private

    def destroy_dokku_service!
      dokku_command_class.call!(ssh, service: dokku_service_id)
    end

    def dokku_command_class
      "Dokku::#{service_type.camelcase}::Destroy".constantize
    end
  end
end
