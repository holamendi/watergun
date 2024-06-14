module ServerActions
  class CreateDomain < ServerAction
    SLUG = "apps.add_domain"

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
      add_dokku_domain!
      actionable.status_created!

      schedule_enable_ssl! if actionable.resolves_to_server?
    end

    private

    def add_dokku_domain!
      Dokku::Domains::Add.call!(ssh, app: dokku_app_id, domain:)
    end

    def schedule_enable_ssl!
      ServerActions::EnableAppSsl.perform_later!(app)
    end
  end
end
