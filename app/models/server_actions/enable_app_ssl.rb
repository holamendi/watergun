module ServerActions
  class EnableAppSsl < ServerAction
    SLUG = "apps.enable_ssl"

    actionable App

    store_attribute :payload, :dokku_app_id, :string

    validates :dokku_app_id, presence: true

    before_validation on: :create do
      self.dokku_app_id ||= app.dokku_id
    end

    private

    def run
      return if all_domains_have_ssl_enabled?

      enable_ssl!
      update_domains
    end

    def all_domains_have_ssl_enabled?
      app.domains.ssl_disabled.empty?
    end

    def enable_ssl!
      Dokku::Letsencrypt::Enable.call!(ssh, app: dokku_app_id)
    end

    def update_domains
      app.domains.update_all(ssl_enabled: true)
    end
  end
end
