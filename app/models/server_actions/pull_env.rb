class ServerActions::PullEnv
  KEY = "apps.pull_env"

  def initialize(run)
    @run = run
  end

  attr_reader :ssh
  delegate :server, :account, :user, :payload, :target, to: :@run
  def app = target
  def dokku_app_id = payload.fetch("dokku_app_id", nil)

  def self.default_payload(target)
    app = target
    {"dokku_app_id" => app.dokku_id}
  end

  def validate!
    ServerAction::TargetValidation.call(@run, type: App, required: %w[dokku_app_id])
  end

  def succeeded!
  end

  def failed!
  end

  def execute!(ssh)
    @ssh = ssh
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
    @dokku_config_export ||= ssh.execute!(Dokku::Config::ExportCommand.new(app: dokku_app_id)).parsed_output
  end

  def out_of_sync_env_variables
    app.env_variables.kept.where.not(name: dokku_config_export.pluck("name"))
  end
end
