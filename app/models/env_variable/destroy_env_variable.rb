class EnvVariable::DestroyEnvVariable
  def initialize(env_variable)
    @env_variable = env_variable
  end

  def destroy
    ServerAction::TargetValidation.app_context!(@env_variable.app)
    raise ArgumentError, "Environment variable ownership mismatch" unless @env_variable.account_id == @env_variable.app.account_id
    raise ArgumentError, "Environment variable is discarded" if @env_variable.discarded?
    editable = !@env_variable.internal? && !@env_variable.internal_in_database && !@env_variable.service_link &&
      !@env_variable.reserved? && !@env_variable.name_in_database&.start_with?(EnvVariable::RESERVED_PREFIX)
    raise ArgumentError, "Environment variable is not editable" unless editable

    ServerAction::Conflict.with_app_lock(@env_variable.app) do
      @env_variable.discard!
      ServerAction::Enqueue.call(action: "apps.update_env", target: @env_variable.app, payload: {unset: [@env_variable.name]})
    end
  end
end
