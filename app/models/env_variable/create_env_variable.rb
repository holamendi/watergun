class EnvVariable::CreateEnvVariable
  attr_reader :server_action_run

  def initialize(env_variable)
    @env_variable = env_variable
  end

  def save(enqueue: true)
    raise ArgumentError, "Environment variable is already persisted" unless @env_variable.new_record?
    return false unless @env_variable.valid?
    ServerAction::TargetValidation.app_context!(@env_variable.app)
    raise ArgumentError, "Environment variable ownership mismatch" unless @env_variable.account_id == @env_variable.app.account_id
    raise ArgumentError, "Environment variable is discarded" if @env_variable.discarded?
    unless @env_variable.editable?
      @env_variable.errors.add(:base, "Environment variable is not editable")
      return false
    end

    ServerAction::Conflict.with_app_lock(@env_variable.app) do |app|
      @env_variable.managed = true
      @env_variable.status = :pending
      @env_variable.save!
      app.increment!(:env_generation)
      @server_action_run = ServerAction::Enqueue.build(action: "apps.update_env", target: @env_variable.app,
        payload: {set: @env_variable.to_h, unset: []})
      ServerAction::Enqueue.persist(server_action_run) if enqueue
    end
    true
  end
end
