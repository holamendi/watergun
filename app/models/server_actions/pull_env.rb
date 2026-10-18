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
    generation = App.where(id: app.id).pick(:env_generation)
    observed = dokku_config_export

    # No row locks during SSH. An export begun before a desired write is not
    # evidence about that intent, even when its remote output arrives later.
    ServerAction::Conflict.with_app_lock(app) do |locked_app|
      next unless locked_app.env_generation == generation

      records = app.env_variables.lock.includes(:service_link).to_a
      observed.each do |attributes|
        matching = records.select { |existing| existing.name == attributes.fetch("name") }
        record = matching.find(&:kept?) || matching.first
        next if record && (record.discarded? || record.account_id != app.account_id)
        next if record&.pending? && record.editable? && record.value != attributes.fetch("value")

        record ||= app.env_variables.new(name: attributes.fetch("name"))
        record.assign_attributes(value: attributes.fetch("value"), status: :synced, synced_at: Time.current)
        record.save!(context: :batch)
      end
      names = observed.pluck("name")
      records.each do |record|
        record.destroy! if record.kept? && record.synced? && record.account_id == app.account_id && record.editable? && !names.include?(record.name)
      end
    end
  end

  def dokku_config_export
    @dokku_config_export ||= ssh.execute!(Dokku::Config::ExportCommand.new(app: dokku_app_id)).parsed_output
  end
end
