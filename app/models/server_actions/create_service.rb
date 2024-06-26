module ServerActions
  class CreateService < ServerAction
    SLUG = "services.create"

    actionable Service

    store_attribute :payload, :dokku_service_id, :string
    store_attribute :payload, :service_type, :string

    validates :dokku_service_id, presence: true
    validates :service_type, presence: true

    before_validation on: :create do
      self.dokku_service_id ||= service.dokku_id
      self.service_type ||= service.service_type
    end

    private

    def run
      return unless plugin_installed? || install_plugin.success?

      create_dokku_service!
      service.data = dokku_service_info
    rescue Ssh::CommandExecutionError
      service.error!
      raise
    else
      service.active!
    end

    def create_dokku_service!
      dokku_service_create_command_class.call!(ssh, service: dokku_service_id)
    end

    def dokku_service_info
      dokku_service_info_command_class.call!(ssh, service: dokku_service_id).parsed_output
    end

    def dokku_service_create_command_class
      "Dokku::#{service_type.camelcase}::Create".constantize
    end

    def dokku_service_info_command_class
      "Dokku::#{service_type.camelcase}::Info".constantize
    end

    memoize def plugins
      Dokku::Plugin::List.call(ssh)
    end

    def plugin_installed?
      plugins.installed?(service_type)
    end

    def install_plugin
      Dokku::Plugin::Install.call!(ssh, plugin: service_type)
    end
  end
end
