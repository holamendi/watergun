class ServerActions::EnableSsl
  KEY = "apps.enable_ssl"

  def initialize(run)
    @run = run
  end

  attr_reader :ssh
  delegate :server, :account, :user, :payload, :target, to: :@run
  def app = target
  def dokku_app_id = payload.fetch("dokku_app_id", nil)

  def self.default_payload(target)
    app = target
    {"dokku_app_id" => app.dokku_id}
  end

  def validate!
    ServerAction::TargetValidation.call(@run, type: App, required: %w[dokku_app_id])
  end

  def succeeded!
    update_domains unless @ssl_already_enabled
  end

  def failed!
    app.domains.enabling_ssl.each(&:active!)
  end

  def execute!(ssh)
    @ssh = ssh
    @ssl_already_enabled = all_domains_have_ssl_enabled?
    return if @ssl_already_enabled

    app.domains.ssl_disabled.each(&:enabling_ssl!)
    enable_ssl!
  end

  def all_domains_have_ssl_enabled?
    app.domains.ssl_disabled.empty?
  end

  def enable_ssl!
    ssh.execute!(Dokku::Letsencrypt::EnableCommand.new(app: dokku_app_id))
  end

  def update_domains
    app.domains.update(ssl_enabled: true, status: :active)
  end
end
