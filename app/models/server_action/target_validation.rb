module ServerAction::TargetValidation
  def self.app_context!(target, account: Current.account || target.account, user: Current.user)
    project = target.is_a?(Project) ? target : target.project
    server = project.server
    available = target.persisted? && project.persisted? && target.kept? && project.kept? &&
      (!target.is_a?(App) || !target.deleted?) && !server.deleted?
    raise ArgumentError, "App or project is unavailable" unless available

    owned = target.account_id == account.id && project.account_id == account.id &&
      server.account_id == account.id && (!target.is_a?(App) || target.server_id == server.id)
    raise ArgumentError, "Target ownership mismatch" unless owned
    if user && !user.memberships.exists?(account_id: account.id)
      raise ArgumentError, "User ownership mismatch"
    end
  end

  def self.call(run, type:, required:)
    target = run.target
    raise ArgumentError, "Target required" unless target.is_a?(type) && target.persisted? && !target.destroyed?
    ownership!(run, target)
    ownership!(run, target.app) if target.respond_to?(:app)
    ownership!(run, target.project) if target.respond_to?(:project)
    raise ArgumentError, "Server ownership mismatch" unless run.server.account_id == run.account_id
    raise ArgumentError, "Payload must be an object" unless run.payload.is_a?(Hash)
    required.each { |key| raise ArgumentError, "Required payload missing" if run.payload[key].blank? }
    defaults = ServerAction::Registry::ACTIONS.fetch(run.action_key).default_payload(target)
    %w[dokku_app_id dokku_service_id hostname host_path container_path service_type project_id].each do |key|
      next unless defaults.key?(key)
      raise ArgumentError, "Target identifier changed" unless defaults[key].to_s == run.payload[key].to_s
    end
    if run.user && !run.user.memberships.exists?(account_id: run.account_id)
      raise ArgumentError, "User ownership mismatch"
    end
  end

  def self.ownership!(run, target)
    server = target.respond_to?(:server) ? target.server : target.app.server
    unless target.account_id == run.account_id && server.id == run.server_id
      raise ArgumentError, "Target ownership mismatch"
    end
  end
end
