class ServerActions::CreateDomain
  KEY = "apps.add_domain"

  def initialize(run)
    @run = run
  end

  attr_reader :ssh
  delegate :server, :account, :user, :payload, :target, to: :@run
  def domain = target
  def dokku_app_id = payload.fetch("dokku_app_id", nil)
  def hostname = payload.fetch("hostname", nil)

  def self.default_payload(target)
    domain = target
    app = target.app
    {"dokku_app_id" => app.dokku_id, "hostname" => domain.hostname}
  end

  def validate!
    ServerAction::TargetValidation.call(@run, type: Domain, required: %w[dokku_app_id hostname])
  end

  def succeeded!
    domain.active!
    schedule_enable_ssl!
  end

  delegate :app, to: :target

  def failed!
    return if domain.destroyed?
    return if @domain_added && domain.reload.active?

    domain.error!
  end

  def execute!(ssh)
    @ssh = ssh
    @domain_added = false
    add_dokku_domain!
    @domain_added = true
  end

  private

  def add_dokku_domain!
    ssh.execute!(Dokku::Domains::AddCommand.new(app: dokku_app_id, domain: hostname))
  end

  def schedule_enable_ssl!
    return unless app.deployed?
    return unless app.all_domains_resolve_to_server?

    ServerAction::Enqueue.call(action: ServerActions::EnableSsl, target: app)
  end
end
