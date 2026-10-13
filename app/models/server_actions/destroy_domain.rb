class ServerActions::DestroyDomain
  KEY = "apps.remove_domain"

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
    target.app
    {"dokku_app_id" => domain.app.dokku_id, "hostname" => domain.hostname}
  end

  def validate!
    ServerAction::TargetValidation.call(@run, type: Domain, required: %w[dokku_app_id hostname])
  end

  def succeeded!
    domain.destroy!
  end

  def failed!
    domain.error! unless domain.destroyed?
  end

  def execute!(ssh)
    @ssh = ssh
    domain.deleting!
    remove_dokku_domain!
  end

  private

  def remove_dokku_domain!
    ssh.execute!(Dokku::Domains::RemoveCommand.new(app: dokku_app_id, domain: hostname))
  end
end
