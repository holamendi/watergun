class ServerActions::RestartApp < ServerAction
  SLUG = "apps.restart"

  actionable App

  store_attribute :payload, :dokku_app_id, :string

  validates :dokku_app_id, presence: true

  before_validation on: :create do
    self.dokku_app_id ||= app.dokku_id
  end

  private

  def run
    app.restarting!
    restart_dokku_app!
    notify_user
  ensure
    app.active!
  end

  def restart_dokku_app!
    Dokku::Ps::Restart.call!(ssh, app: dokku_app_id)
  end

  def notify_user
    user.notify_later("#{app.name}: restart finished")
  end
end
