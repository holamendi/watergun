module ServerActions
  class CreateApp < ServerAction
    SLUG = "apps.create"

    alias_method :app, :actionable

    store_attribute :payload, :dokku_app_id, :string

    validates :dokku_app_id, presence: true

    before_validation on: :create do
      self.dokku_app_id ||= app.dokku_id
    end

    def perform
      create_dokku_app!
      create_domains!
    end

    private

    def create_dokku_app!
      Dokku::Apps::Create.call!(ssh, app: dokku_app_id)
    end

    def create_domains!
      dokku_app_hostnames.each { |hostname| app.domains.create!(hostname:) }
    end

    def dokku_app_hostnames
      Dokku::Domains::Report.call!(ssh, app: dokku_app_id).domains_app_vhosts
    end
  end
end
