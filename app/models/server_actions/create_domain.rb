class ServerActions::CreateDomain < ServerAction
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

  def on_failure
    return if domain.destroyed?
    return if @domain_added && domain.reload.active?

    domain.error!
  end

  def run
    @domain_added = false
    add_dokku_domain!
    @domain_added = true
    domain.active!
    schedule_enable_ssl!
  end

  private

  def add_dokku_domain!
    execute!(Dokku::Domains::AddCommand.new(app: dokku_app_id, domain: hostname))
  end

  def schedule_enable_ssl!
    return unless app.deployed?
    return unless app.all_domains_resolve_to_server?

    ServerActions::EnableSsl.run_later!(server, app)
  end
end
