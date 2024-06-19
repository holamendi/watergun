module ServerActions
  class DestroyDomain < ServerAction
    SLUG = "apps.remove_domain"

    actionable Domain

    store_attribute :payload, :dokku_app_id, :string
    store_attribute :payload, :domain, :string

    validates :dokku_app_id, presence: true
    validates :domain, presence: true

    before_validation on: :create do
      self.dokku_app_id ||= domain.app.dokku_id
      self.hostname ||= domain.hostname
    end

    def concurrency_key
      domain.app
    end

    def perform
      remove_dokku_domain!
      domain.status_destroyed!
    end

    private

    def remove_dokku_domain!
      Dokku::Domains::Remove.call!(ssh, app: dokku_app_id, domain: hostname)
    end
  end
end
