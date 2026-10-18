class EnvVariable::UpdateEnvVariable
  attr_reader :server_action_run

  def initialize(env_variable)
    @env_variable = env_variable
  end

  def save(enqueue: true)
    raise ArgumentError, "Environment variable must be persisted" unless @env_variable.persisted?
    return false unless @env_variable.valid?
    ServerAction::TargetValidation.app_context!(@env_variable.app)
    raise ArgumentError, "Environment variable ownership mismatch" unless @env_variable.account_id == @env_variable.app.account_id
    intended = @env_variable.attributes.slice("name", "value")
    ServerAction::Conflict.with_app_lock(@env_variable.app) do |app|
      @env_variable.reload(lock: true)
      raise ArgumentError, "Environment variable ownership mismatch" unless @env_variable.account_id == app.account_id && @env_variable.app_id == app.id
      raise ArgumentError, "Environment variable is discarded" if @env_variable.discarded?
      unless @env_variable.editable?
        @env_variable.errors.add(:base, "Environment variable is not editable")
        return false
      end
      @env_variable.assign_attributes(intended)
      return false unless @env_variable.valid?
      changed = @env_variable.name_changed? || @env_variable.value_changed?
      claimed = !@env_variable.managed?
      @env_variable.managed = true
      @env_variable.status = :pending if changed
      @env_variable.save!
      app.increment!(:env_generation) if changed || claimed
      if changed
        unset = (@env_variable.saved_change_to_name? && @env_variable.name_before_last_save) ? [@env_variable.name_before_last_save] : []
        @server_action_run = ServerAction::Enqueue.build(action: "apps.update_env", target: @env_variable.app,
          payload: {set: @env_variable.to_h, unset:})
        ServerAction::Enqueue.persist(server_action_run) if enqueue
      end
    end
    true
  end
end
