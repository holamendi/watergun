class EnvVariable::WriteEnvVariables
  include ActiveModel::Model

  attr_accessor :app, :mode, :values
  attr_reader :server_action_run

  def save
    valid = mode.in?(%w[merge replace]) && values.is_a?(Hash) && values.size <= 100 && values.all? do |name, value|
      name.is_a?(String) && name.length <= 128 && name.match?(EnvVariable::NAME_REGEX) &&
        !name.start_with?(EnvVariable::RESERVED_PREFIX) &&
        (value.nil? || (value.is_a?(String) && value.length <= 16_384 && !value.include?("\0")))
    end
    unless valid
      errors.add(:base, "Invalid environment batch")
      return false
    end
    ServerAction::TargetValidation.app_context!(app)
    ServerAction::Conflict.with_app_lock(app) do |locked_app|
      records = app.env_variables.kept.lock.includes(:service_link).to_a
      protected = records.select { |record| record.account_id != app.account_id || record.internal? || record.reserved? || record.service_link }
      if (protected.map(&:name) & values.keys).any?
        errors.add(:base, "Environment variable is not editable")
        return false
      end
      editable = records - protected
      unset = editable.select { |record| values[record.name].nil? && (values.key?(record.name) || (mode == "replace" && record.managed?)) }
      set = values.reject { |_name, value| value.nil? }
      set.each do |name, value|
        record = editable.find { |existing| existing.name == name } || app.env_variables.new(name: name)
        record.value = value
        record.managed = true
        record.status = :pending
        record.save!(context: :batch)
      end
      unset.each(&:discard!)
      locked_app.increment!(:env_generation) if set.any? || unset.any?
      app.pending_restart! if set.any? || unset.any?
      @server_action_run = ServerAction::Enqueue.call(action: "apps.update_env", target: app,
        payload: {set: set, unset: unset.map(&:name)})
    end
    true
  end
end
