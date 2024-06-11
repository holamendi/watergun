module ServerActions
  class CreateService < ServerAction
    SLUG = "services.create"

    alias_method :service, :actionable

    store_attribute :payload, :dokku_service_id, :string
    store_attribute :payload, :service_type, :string

    validates :dokku_service_id, presence: true

    before_validation on: :create do
      self.service_type ||= service.service_type
      self.dokku_service_id ||= service.dokku_id
    end

    def perform
      return unless plugin_installed? || install_plugin.success?

      result = dokku_service_create_command_class.call(ssh, service: dokku_service_id)
      return unless result.success?

      service.data = dokku_service_info_command_class.call(ssh, service: dokku_service_id).parsed_output
      service.status_created!
    end

    private

    def dokku_service_create_command_class
      "Dokku::#{service_type.camelcase}::Create".constantize
    end

    def dokku_service_info_command_class
      "Dokku::#{service_type.camelcase}::Info".constantize
    end

    def plugins
      @plugins ||= Dokku::Plugin::List.call(ssh)
    end

    def plugin_installed?
      plugins.installed?(service_type)
    end

    def install_plugin!
      Dokku::Plugin::Install.call(ssh, plugin: service_type)
    end
  end
end
