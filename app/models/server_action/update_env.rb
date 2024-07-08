class ServerAction::UpdateEnv < ServerAction
  SLUG = "apps.update_env"

  actionable App

  store_attribute :payload, :dokku_app_id, :string
  store_attribute :payload, :set, :json, default: {}
  store_attribute :payload, :unset, :json, default: []
  store_attribute :payload, :restart, :boolean, default: false

  validates :dokku_app_id, presence: true
  validates :restart, inclusion: {in: [true, false]}

  before_validation on: :create do
    self.dokku_app_id ||= app.dokku_id
  end

  def concurrency_key
    app
  end

  private

  def run
    if set.present?
      set_env_variables.update!(status: :syncing)
      set_dokku_app_config!
      synced_at = Time.current
      set_env_variables.update!(status: :synced, synced_at:)
    end

    if unset.present?
      unset_env_variables.update!(status: :syncing)
      unset_dokku_app_config!
      unset_env_variables.update_all(status: :synced, synced_at: Time.current)
    end

    schedule_restart! if restart
  end

  def set_dokku_app_config!
    Dokku::Config::Set.call!(ssh, app: dokku_app_id, env: set)
  end

  def unset_dokku_app_config!
    Dokku::Config::Unset.call!(ssh, app: dokku_app_id, variable_names: unset)
  end

  def schedule_restart!
    ServerAction::RestartApp.run_later!(app)
  end

  memoize def set_env_variables
    app.env_variables.where(key: set.keys)
  end

  memoize def unset_env_variables
    app.env_variables.where(key: unset)
  end
end
