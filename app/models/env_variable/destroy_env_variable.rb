class EnvVariable::DestroyEnvVariable
  attr_reader :server_action_run

  def initialize(env_variable)
    @env_variable = env_variable
  end

  def destroy(enqueue: true)
    ServerAction::TargetValidation.app_context!(@env_variable.app)
    raise ArgumentError, "Environment variable ownership mismatch" unless @env_variable.account_id == @env_variable.app.account_id
    ServerAction::Conflict.with_app_lock(@env_variable.app) do |app|
      @env_variable.reload(lock: true)
      raise ArgumentError, "Environment variable ownership mismatch" unless @env_variable.account_id == app.account_id && @env_variable.app_id == app.id
      raise ArgumentError, "Environment variable is discarded" if @env_variable.discarded?
      raise ArgumentError, "Environment variable is not editable" unless @env_variable.editable?
      @env_variable.discard!
      app.increment!(:env_generation)
      @server_action_run = ServerAction::Enqueue.build(action: "apps.update_env", target: @env_variable.app, payload: {unset: [@env_variable.name]})
      enqueue ? ServerAction::Enqueue.persist(server_action_run) : server_action_run
    end
  end
end
