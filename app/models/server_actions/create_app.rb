class ServerActions::CreateApp < ServerAction
  SLUG = "apps.create"

  actionable App

  store_attribute :payload, :dokku_app_id, :string

  validates :dokku_app_id, presence: true

  before_validation on: :create do
    self.account ||= app.account
    self.server ||= app.server
    self.dokku_app_id ||= app.dokku_id
  end

  private

  def run
    create_dokku_app!
    create_domains!
    create_service_links!
  rescue Ssh::CommandExecutionError
    app.error!
    raise
  else
    app.active!
  end

  def create_dokku_app!
    ssh.execute!(Dokku::Apps::CreateCommand.new(app: dokku_app_id))
  end

  def create_domains!
    dokku_app_hostnames.each_with_index do |hostname, index|
      app.domains.create!(hostname:, status: :active, is_default: index.zero?)
    end
  end

  def create_service_links!
    app.project.services.kept.each do |service|
      ServiceLink::CreateServiceLink.new(service:, app:).save
    end
  end

  def dokku_app_hostnames
    ssh.execute!(Dokku::Domains::ReportCommand.new(app: dokku_app_id)).parsed_output.domains_app_vhosts
  end
end
