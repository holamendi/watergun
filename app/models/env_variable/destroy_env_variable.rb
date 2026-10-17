class EnvVariable::DestroyEnvVariable
  def initialize(env_variable)
    @env_variable = env_variable
  end

  def destroy
    EnvVariable::MutationValidation.validate!(@env_variable)
    raise ArgumentError, "Environment variable is not editable" unless EnvVariable::MutationValidation.editable?(@env_variable)

    EnvVariable.transaction do
      @env_variable.discard!
      ServerAction::Enqueue.call(action: "apps.update_env", target: @env_variable.app, payload: {unset: [@env_variable.name]})
    end
  end
end
