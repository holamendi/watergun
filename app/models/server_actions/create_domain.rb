module ServerActions
  class CreateDomain < ServerAction
    SLUG = "apps.add_domain"

    actionable Domain

    store_attribute :payload, :dokku_app_id, :string
    store_attribute :payload, :hostname, :string

    validates :dokku_app_id, presence: true
    validates :hostname, presence: true

    delegate :app, to: :actionable

    before_validation on: :create do
      self.dokku_app_id ||= app.dokku_id
      self.hostname ||= domain.hostname
    end

    def concurrency_key
      app
    end

    def perform
      add_dokku_domain!
    rescue Ssh::CommandExecutionError
      domain.error!
      raise
    else
      domain.active!
      schedule_enable_ssl!
    end

    private

    def add_dokku_domain!
      Dokku::Domains::Add.call!(ssh, app: dokku_app_id, domain: hostname)
    end

    def schedule_enable_ssl!
      return unless app.deployed?
      return unless app.domains.kept.all? { |domain| domain.resolves_to_server? }

      ServerActions::EnableAppSsl.perform_later!(domain.app)
    end
  end
end
