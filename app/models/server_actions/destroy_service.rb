class ServerActions::DestroyService < ServerAction
  SLUG = "services.destroy"

  actionable Service

  store_attribute :payload, :dokku_service_id, :string
  store_attribute :payload, :service_type, :string

  validates :dokku_service_id, presence: true

  before_validation on: :create do
    self.service_type ||= service.service_type
    self.dokku_service_id ||= service.dokku_id
  end

  def on_failure
    service.error!
  end

  private

  def run
    service.deleting!
    destroy_dokku_service!
    service.destroy!
  end

  def destroy_dokku_service!
    ssh.execute!(Dokku::Services::DestroyCommand.new(plugin: service_type, name: dokku_service_id))
  end
end
