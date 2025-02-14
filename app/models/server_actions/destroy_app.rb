class ServerActions::DestroyApp < ServerAction
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
  rescue Ssh::CommandExecutionError
    app.error!
    raise
  else
    app.destroy!
  end

  def destroy_dokku_app!
    execute!(Dokku::Apps::DestroyCommand.new(app: dokku_app_id))
  end
end
