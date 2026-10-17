class EnvVariable::UpdateEnvVariable
  def initialize(env_variable)
    @env_variable = env_variable
  end

  def save
    raise ArgumentError, "Environment variable must be persisted" unless @env_variable.persisted?
    return false unless @env_variable.valid?
    EnvVariable::MutationValidation.validate!(@env_variable)
    unless EnvVariable::MutationValidation.editable?(@env_variable)
      @env_variable.errors.add(:base, "Environment variable is not editable")
      return false
    end

    EnvVariable.transaction do
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
