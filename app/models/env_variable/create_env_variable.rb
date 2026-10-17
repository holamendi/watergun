class EnvVariable::CreateEnvVariable
  def initialize(env_variable)
    @env_variable = env_variable
  end

  def save
    raise ArgumentError, "Environment variable is already persisted" unless @env_variable.new_record?
    return false unless @env_variable.valid?
    EnvVariable::MutationValidation.validate!(@env_variable)
    unless EnvVariable::MutationValidation.editable?(@env_variable)
      @env_variable.errors.add(:base, "Environment variable is not editable")
      return false
    end

    EnvVariable.transaction do
      @env_variable.save!
      ServerAction::Enqueue.call(action: "apps.update_env", target: @env_variable.app,
        payload: {set: @env_variable.to_h, unset: []})
    end
    true
  end
end
