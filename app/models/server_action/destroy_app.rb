class ServerAction::DestroyApp < ServerAction
  SLUG = "apps.destroy"

  actionable App

  store_attribute :payload, :dokku_app_id, :string

  validates :dokku_app_id, presence: true

  before_validation on: :create do
    self.dokku_app_id ||= app.dokku_id
  end

  private

  def run
    app.deleting!
    destroy_dokku_app!
    unlink_and_discard_service_links
  rescue Ssh::CommandExecutionError
    app.error!
    raise
  else
    app.deleted!
  end

  def destroy_dokku_app!
    Dokku::Apps::Destroy.call!(ssh, app: dokku_app_id)
  end

  def unlink_and_discard_service_links
    app.service_links.update_all(status: :unlinked, discarded_at: Time.current)
  end
end
