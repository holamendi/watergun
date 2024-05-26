module ServerActions
  class DestroyApp < ServerAction
    ACTION_CODE = "apps.destroy"

    alias_method :app, :actionable

    store_attribute :payload, :dokku_app_id, :string

    validates :dokku_app_id, presence: true

    before_validation on: :create do
      self.dokku_app_id ||= app.dokku_id
    end

    def perform
      result = Dokku::Apps::Destroy.call(ssh, app: dokku_app_id)
      app.service_links.update_all(status: :unlinked, discarded_at: Time.current) if result.success?
    end
  end
end
