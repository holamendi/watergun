module ServerActions
  class CreateDokkuService < ServerAction
    alias_method :service, :actionable

    store_attribute :payload, :dokku_service_id, :string
    store_attribute :payload, :service_type, :string

    validates :dokku_service_id, presence: true

    before_validation on: :create do
      self.service_type ||= service.service_type
      self.dokku_service_id ||= service.dokku_id
    end

    def perform
      ssh_session { |ssh| dokku_command_class.call(ssh, service: dokku_service_id) }
    end

    private

    def dokku_command_class
      "Dokku::#{service_type.camelcase}::Create".constantize
    end
  end
end
