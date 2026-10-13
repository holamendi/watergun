class ServerActions::DestroyProject < ServerAction
  SLUG = "projects.destroy"

  actionable Project

  store_attribute :payload, :project_id, :string

  validates :project_id, presence: true
  validate :project_matches_server, on: :create

  before_validation on: :create do
    self.project_id = project.id
  end

  private

  def project_matches_server
    if project && server && (project.server_id != server_id || project.account_id != server.account_id || account_id != server.account_id)
      errors.add(:actionable, "must belong to the action server and account")
    end

    if project && server && project.apps.any? { |app| app.server_id != server_id || app.account_id != account_id }
      errors.add(:actionable, "apps must belong to the action server and account")
    end

    if project && server && project.services.any? { |service| service.server_id != server_id || service.account_id != account_id }
      errors.add(:actionable, "services must belong to the action server and account")
    end
  end

  def run
    project.reload
    errors.clear
    project_matches_server
    raise ActiveRecord::RecordInvalid, self if errors.any?

    destroy_dokku_apps!
    destroy_dokku_services!
    project.destroy!
  end

  def destroy_dokku_apps!
    project.apps.kept.each do |app|
      execute!(Dokku::Apps::DestroyCommand.new(app: app.dokku_id))
      app.destroy!
    end
  end

  def destroy_dokku_services!
    project.services.kept.each do |service|
      execute!(Dokku::Services::DestroyCommand.new(plugin: service.service_type, name: service.dokku_id))
      service.destroy!
    end
  end
end
