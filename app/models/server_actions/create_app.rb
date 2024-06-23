module ServerActions
  class CreateApp < ServerAction
    SLUG = "apps.create"

    actionable App

    store_attribute :payload, :dokku_app_id, :string

    validates :dokku_app_id, presence: true

    before_validation on: :create do
      self.dokku_app_id ||= app.dokku_id
    end

    private

    def perform
      create_dokku_app!
      create_domains!
    rescue Ssh::CommandExecutionError
      app.error!
      raise
    else
      app.active!
    end

    def create_dokku_app!
      Dokku::Apps::Create.call!(ssh, app: dokku_app_id)
    end

    def create_domains!
      dokku_app_hostnames.each_with_index do |hostname, index|
        app.domains.create!(hostname:, status: :active, is_default: index.zero?)
      end
    end

    def dokku_app_hostnames
      Dokku::Domains::Report.call!(ssh, app: dokku_app_id).domains_app_vhosts
    end
  end
end
