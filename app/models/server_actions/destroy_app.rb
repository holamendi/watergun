module ServerActions
  class DestroyApp < ServerAction
    SLUG = "apps.destroy"

    alias_method :app, :actionable

    store_attribute :payload, :dokku_app_id, :string

    validates :dokku_app_id, presence: true

    before_validation on: :create do
      self.dokku_app_id ||= app.dokku_id
    end

    def perform
      destroy_dokku_app!
      unlink_service_links
    end

    private

    def destroy_dokku_app!
      Dokku::Apps::Destroy.call!(ssh, app: dokku_app_id)
    end

    def unlink_service_links
      app.service_links.update_all(status: :unlinked, discarded_at: Time.current)
    end
  end
end
