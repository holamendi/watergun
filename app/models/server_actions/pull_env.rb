class ServerActions::PullEnv < ServerAction
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

    # sync env variables
    EnvVariable.upsert_all(upsert_env_variables, unique_by: %i[app_id name]) if upsert_env_variables.any?
    # delete out of sync env variables
    out_of_sync_env_variables.destroy_all
  end

  def dokku_config_export
    @dokku_config_export ||= execute!(Dokku::Config::ExportCommand.new(app: dokku_app_id)).parsed_output
  end

  def out_of_sync_env_variables
    app.env_variables.kept.where.not(name: dokku_config_export.pluck("name"))
  end
end
