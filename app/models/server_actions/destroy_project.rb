class ServerActions::DestroyProject
  KEY = "projects.destroy"

  def initialize(run)
    @run = run
  end

  attr_reader :ssh
  delegate :server, :account, :user, :payload, :target, to: :@run
  def project = target
  def project_id = payload.fetch("project_id", nil)

  def self.default_payload(target)
    project = target
    {"project_id" => project.id}
  end

  def validate!
    ServerAction::TargetValidation.call(@run, type: Project, required: %w[project_id])
    (project.apps.to_a + project.services.to_a).each { |child| ServerAction::TargetValidation.ownership!(@run, child) }
  end

  def succeeded!
  end

  def failed!
  end

  def execute!(ssh)
    @ssh = ssh

    destroy_dokku_apps!
    destroy_dokku_services!
    project.destroy!
  end

  def destroy_dokku_apps!
    project.apps.kept.each do |app|
      ssh.execute!(Dokku::Apps::DestroyCommand.new(app: app.dokku_id))
      app.destroy!
    end
  end

  def destroy_dokku_services!
    project.services.kept.each do |service|
      ssh.execute!(Dokku::Services::DestroyCommand.new(plugin: service.service_type, name: service.dokku_id))
      service.destroy!
    end
  end
end
