class ServerActions::DestroyProject < ServerAction
  SLUG = "projects.destroy"

  actionable Project

  store_attribute :payload, :project_id, :string

  validates :project_id, presence: true

  before_validation on: :create do
    self.project_id = project.id
  end

  private

  def run
    destroy_dokku_apps!
    destroy_dokku_services!
  rescue Ssh::CommandExecutionError
  else
    project.destroy!
  end

  def destroy_dokku_apps!
    project.apps.each do |app|
      ssh.execute(Dokku::Apps::DestroyCommand.new(app: app.dokku_id))
      app.destroy!
    end
  end

  def destroy_dokku_services!
    project.services.kept.each do |service|
      ssh.execute(Dokku::Services::DestroyCommand.new(plugin: service.service_type, name: service.name))
      service.destroy!
    end
  end
end
