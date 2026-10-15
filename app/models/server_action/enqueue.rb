class ServerAction::Enqueue
  def self.build(action:, target:, payload: {}, user: Current.user, server: target.server, account: target.account, source: Current.source.presence || "web")
    action_class = ServerAction::Registry.fetch(action)
    run = ServerActionRun.new(action_key: action, target: target, server: server, account: account,
      user: user, source: source, payload: action_class.default_payload(target).merge(payload.deep_stringify_keys),
      resource_key: ServerAction::ResourceKey.for(target))
    ServerAction::Registry.build(run).validate!
    run
  end

  def self.call(**attributes)
    run = build(**attributes)
    run.save!
    ActiveRecord.after_all_transactions_commit { schedule(run) }
    run
  end

  def self.schedule(run)
    run.with_lock do
      raise ArgumentError, "Run has already started or been scheduled" unless run.queued? && run.enqueued_at.nil?
      ServerAction::Registry.build(run).validate!
      run.update!(resource_key: ServerAction::ResourceKey.for(run.target))
      job = RunServerActionJob.new(run.id, run.resource_key)
      result = job.enqueue
      raise(job.enqueue_error || ActiveJob::EnqueueError.new("Action was not enqueued")) unless result && job.successfully_enqueued?
      run.update!(enqueued_at: Time.current, scheduling_failed_at: nil, failure_message: nil)
    end
    run
  rescue => error
    begin
      run.update_columns(scheduling_failed_at: Time.current, failure_message: "Scheduling failed (#{error.class.name})") if run.persisted? && run.queued? && run.enqueued_at.nil?
    rescue => bookkeeping_error
      ServerAction::Runner.report(bookkeeping_error, run.id, phase: "scheduling bookkeeping")
    end
    raise error
  end
end
