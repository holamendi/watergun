class EnvVariable::UpdateEnvVariable
  def initialize(env_variable)
    @env_variable = env_variable
  end

  def save
    raise ArgumentError, "Environment variable must be persisted" unless @env_variable.persisted?
    return false unless @env_variable.valid?
    ServerAction::TargetValidation.app_context!(@env_variable.app)
    raise ArgumentError, "Environment variable ownership mismatch" unless @env_variable.account_id == @env_variable.app.account_id
    intended = @env_variable.attributes.slice("name", "value")
    ServerAction::Conflict.with_app_lock(@env_variable.app) do |app|
      @env_variable.reload.lock!
      raise ArgumentError, "Environment variable ownership mismatch" unless @env_variable.account_id == app.account_id && @env_variable.app_id == app.id
      raise ArgumentError, "Environment variable is discarded" if @env_variable.discarded?
      unless @env_variable.editable?
        @env_variable.errors.add(:base, "Environment variable is not editable")
        return false
      end
      @env_variable.assign_attributes(intended)
      return false unless @env_variable.valid?
      changed = @env_variable.name_changed? || @env_variable.value_changed?
      @env_variable.managed = true
      @env_variable.status = :pending if changed
      @env_variable.save!
      if changed
        app.increment!(:env_generation)
        unset = (@env_variable.saved_change_to_name? && @env_variable.name_before_last_save) ? [@env_variable.name_before_last_save] : []
        ServerAction::Enqueue.call(action: "apps.update_env", target: @env_variable.app,
          payload: {set: @env_variable.to_h, unset:})
      end
    end
    true
  end
end
