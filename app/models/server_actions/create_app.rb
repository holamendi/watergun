class ServerActions::CreateApp
  KEY = "apps.create"

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
    create_domains!
    create_service_links!
    @creation_completed = true
    app.active!
  end

  def failed!
    return if app.destroyed? || (@creation_completed && app.reload.active?)

    app.error!
  end

  def execute!(ssh)
    @ssh = ssh
    create_dokku_app!
  end

  def create_dokku_app!
    ssh.execute!(Dokku::Apps::CreateCommand.new(app: dokku_app_id))
  end

  def create_domains!
    dokku_app_hostnames.each_with_index do |hostname, index|
      app.domains.create!(hostname:, status: :active, is_default: index.zero?)
    end
  end

  def dokku_app_hostnames
    ssh.execute!(Dokku::Domains::ReportCommand.new(app: dokku_app_id)).parsed_output.domains_app_vhosts
  end

  def create_service_links!
    app.project.services.kept.each do |service|
      ServiceLink::CreateServiceLink.new(service:, app:).save!
    end
  end
end
