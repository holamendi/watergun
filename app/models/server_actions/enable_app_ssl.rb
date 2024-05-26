module ServerActions
  class EnableAppSsl < ServerAction
    ACTION_CODE = "apps.enable_ssl"

    alias_method :app, :actionable

    store_attribute :payload, :dokku_app_id, :string

    validates :dokku_app_id, presence: true

    before_validation on: :create do
      self.dokku_app_id ||= app.dokku_id
    end

    def perform
      return if ssl_enabled?

      result = Dokku::Letsencrypt::Enable.call(ssh, app: dokku_app_id)
      update_app_urls! if result.success?
    end

    private

    def update_app_urls!
      urls = Dokku::Urls.call(ssh, app: dokku_app_id).parse
      app.update!(urls:) if urls.present?
    end

    def ssl_enabled?
      Dokku::Letsencrypt::Active.call(ssh, app: dokku_app_id).parse
    end
  end
end
