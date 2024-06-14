module ServerActions
  class DestroyDomain < ServerAction
    SLUG = "apps.remove_domain"

    store_attribute :payload, :dokku_app_id, :string
    store_attribute :payload, :domain, :string

    validates :dokku_app_id, presence: true
    validates :domain, presence: true

    delegate :app, to: :actionable

    before_validation on: :create do
      self.dokku_app_id ||= app.dokku_id
      self.domain ||= actionable.hostname
    end

    def concurrency_key
      app
    end

    def perform
      remove_dokku_domain!
      actionable.status_destroyed!
    end

    private

    def remove_dokku_domain!
      Dokku::Domains::Remove.call!(ssh, app: dokku_app_id, domain:)
    end
  end
end
