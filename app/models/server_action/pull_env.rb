class ServerAction::PullEnv < ServerAction
  SLUG = "apps.pull_env"

  actionable App

  store_attribute :payload, :dokku_app_id, :string

  validates :dokku_app_id, presence: true

  before_validation on: :create do
    self.dokku_app_id ||= app.dokku_id
  end

  def concurrency_key
    app
  end

  private

  def run
    synced_at = Time.current

    upsert_env_variables = dokku_config_export.map do |env_variable|
      env_variable.merge(
        account_id: app.account_id,
        app_id: app.id,
        status: :synced,
        synced_at:
      )
    end

    EnvVariable.upsert_all(upsert_env_variables, unique_by: %i[app_id name])
  end

  def dokku_config_export
    Dokku::Config::Export.call!(ssh, app: dokku_app_id).parsed_output
  end
end
