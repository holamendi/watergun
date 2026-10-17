module EnvVariable::MutationValidation
  def self.validate!(env_variable)
    ServerAction::TargetValidation.app_context!(env_variable.app)
    raise ArgumentError, "Environment variable ownership mismatch" unless env_variable.account_id == env_variable.app.account_id
    raise ArgumentError, "Environment variable is discarded" if env_variable.discarded?
  end

  def self.editable?(env_variable)
    !env_variable.internal? && !env_variable.internal_in_database && !env_variable.service_link &&
      !env_variable.reserved? && !env_variable.name_in_database&.start_with?(EnvVariable::RESERVED_PREFIX)
  end
end
