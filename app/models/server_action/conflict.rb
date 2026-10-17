module ServerAction::Conflict
  ACTIONS = %w[apps.create apps.deploy apps.restart apps.destroy apps.update_env apps.set_builder].freeze
  class Error < StandardError
    def initialize = super("App has conflicting work")
  end

  def self.app_for(run)
    case run.target
    when App then run.target
    when Deployment then run.target.app
    end
  end

  def self.guard(run)
    app = app_for(run)
    return yield unless app && ACTIONS.include?(run.action_key)

    # Held through the caller's transaction: rejected preparation is rolled back.
    App.transaction do
      App.lock.find(app.id)
      run.target.reload
      ServerAction::Registry.build(run).validate!
      candidates = ServerActionRun.where(account_id: run.account_id, server_id: run.server_id, action_key: ACTIONS)
        .where("status IN ('queued', 'running') OR outcome_uncertain = TRUE")
        .where.not(id: Current.executing_server_action&.id)
      busy = candidates.any? { |candidate| app_for(candidate)&.id == app.id || candidate.operation_app_id == app.id }
      raise Error if busy
      yield
    end
  end
end
