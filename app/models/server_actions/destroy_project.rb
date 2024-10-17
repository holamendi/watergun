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
  ensure
    project.destroy!
  end

  def destroy_dokku_apps!
    project.apps.kept.each { ServerActions::DestroyApp.run_now!(_1) }
  end

  def destroy_dokku_services!
    project.services.kept.each { ServerActions::DestroyService.run_now!(_1) }
  end
end
