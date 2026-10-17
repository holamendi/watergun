class EnvVariable::UpdateEnvVariable
  def initialize(env_variable)
    @env_variable = env_variable
  end

  def save
    raise ArgumentError, "Environment variable must be persisted" unless @env_variable.persisted?
    return false unless @env_variable.valid?
    ServerAction::TargetValidation.app_context!(@env_variable.app)
    raise ArgumentError, "Environment variable ownership mismatch" unless @env_variable.account_id == @env_variable.app.account_id
    raise ArgumentError, "Environment variable is discarded" if @env_variable.discarded?
    editable = !@env_variable.internal? && !@env_variable.internal_in_database && !@env_variable.service_link &&
      !@env_variable.reserved? && !@env_variable.name_in_database&.start_with?(EnvVariable::RESERVED_PREFIX)
    unless editable
      @env_variable.errors.add(:base, "Environment variable is not editable")
      return false
    end

    ServerAction::Conflict.with_app_lock(@env_variable.app) do
      @env_variable.save!
      if @env_variable.saved_change_to_name? || @env_variable.saved_change_to_value?
        unset = (@env_variable.saved_change_to_name? && @env_variable.name_before_last_save) ? [@env_variable.name_before_last_save] : []
        ServerAction::Enqueue.call(action: "apps.update_env", target: @env_variable.app,
          payload: {set: @env_variable.to_h, unset:})
      end
    end
    true
  end
end
