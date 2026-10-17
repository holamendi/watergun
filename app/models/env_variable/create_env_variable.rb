class EnvVariable::CreateEnvVariable
  def initialize(env_variable)
    @env_variable = env_variable
  end

  def save
    raise ArgumentError, "Environment variable is already persisted" unless @env_variable.new_record?
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
      ServerAction::Enqueue.call(action: "apps.update_env", target: @env_variable.app,
        payload: {set: @env_variable.to_h, unset: []})
    end
    true
  end
end
