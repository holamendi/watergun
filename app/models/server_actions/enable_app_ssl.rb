module ServerActions
  class EnableAppSsl < ServerAction
    SLUG = "apps.enable_ssl"

    alias_method :app, :actionable

    store_attribute :payload, :dokku_app_id, :string

    validates :dokku_app_id, presence: true

    before_validation on: :create do
      self.dokku_app_id ||= app.dokku_id
    end

    def perform
      return if ssl_enabled?

      enable_ssl!
      update_app_urls!
    end

    private

    def ssl_enabled?
      Dokku::Letsencrypt::Active.call!(ssh, app: dokku_app_id).parsed_output
    end

    def enable_ssl!
      Dokku::Letsencrypt::Enable.call!(ssh, app: dokku_app_id)
    end

    def update_app_urls!
      urls = Dokku::Urls.call(ssh, app: dokku_app_id).parsed_output
      app.update!(urls:) if urls.present?
    end
  end
end
