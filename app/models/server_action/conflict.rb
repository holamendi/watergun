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
    if run.action_key == "projects.destroy"
      return Project.transaction do
        run.target.lock!
        ServerAction::Registry.build(run).validate!
        check_project!(run.target)
        yield
      end
    end
    app = app_for(run)
    return yield unless app && ACTIONS.include?(run.action_key)

    # Held through the caller's transaction: rejected preparation is rolled back.
    with_app_lock(app) do
      run.target.reload
      ServerAction::Registry.build(run).validate!
      raise Error if pending.where(action_key: "projects.destroy", target: app.project).exists?
      candidates = pending.where(account_id: run.account_id, server_id: run.server_id, action_key: ACTIONS)
      busy = candidates.any? { |candidate| app_for(candidate)&.id == app.id || candidate.operation_app_id == app.id }
      raise Error if busy
      yield
    end
  end

  # Match worker app status updates, which touch their project after the app.
  # Parent deletion locks only the project and rejects pending child work.
  def self.with_app_lock(app)
    App.transaction do
      locked_app = App.lock.find(app.id)
      raise Error unless locked_app.project_id == app.project_id
      Project.lock.find(locked_app.project_id)
      yield
    end
  end

  def self.pending
    ServerActionRun.where("status IN ('queued', 'running') OR outcome_uncertain = TRUE")
      .where.not(id: Current.executing_server_action&.id)
  end

  def self.check_project!(project, excluding: nil)
    ids = project.apps.pluck(:id)
    candidates = pending.where.not(id: excluding)
    raise Error if candidates.where(action_key: "projects.destroy", target: project).exists?
    busy = candidates.where(account_id: project.account_id, action_key: ACTIONS).any? do |candidate|
      ids.include?(app_for(candidate)&.id) || ids.include?(candidate.operation_app_id)
    end
    raise Error if busy
  end
end
