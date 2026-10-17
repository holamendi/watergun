class ServerAction::Recovery
  def self.call
    # Run by the recurring scheduler after restart as well as by an operator.
    # Queue delivery can repeat; the atomic execution claim cannot.
    ServerActionRun.where(status: %w[queued running]).find_each do |run|
      recover(run)
    rescue => error
      ServerAction::Runner.report(error, run.id, phase: "recovery")
    end
  end

  def self.recover(run)
    resource = run.target ? ServerAction::ResourceKey.for(run.target) : run.resource_key
    lock_key = Digest::SHA256.digest(resource).unpack1("q>")
    ServerActionRun.connection_pool.with_connection do |connection|
      next unless connection.select_value("SELECT pg_try_advisory_lock(#{lock_key})")
      begin
        run.with_lock do
          if run.running?
            completed = run.remote_completed_at.present?
            run.update!(status: completed ? :success : :error, finished_at: Time.current,
              public_error_code: completed ? nil : "outcome_unknown", outcome_uncertain: !completed,
              dispatch_pending_at: nil)
          elsif run.queued? && (run.enqueued_at.nil? || run.enqueued_at < 5.minutes.ago)
            run.update!(enqueued_at: nil, dispatch_pending_at: run.dispatch_pending_at || Time.current)
            begin
              ServerAction::Enqueue.schedule(run)
            rescue ArgumentError, KeyError
              run.update!(status: :error, public_error_code: "dispatch_failed", finished_at: Time.current,
                dispatch_pending_at: nil)
            end
          end
        end
      ensure
        connection.execute("SELECT pg_advisory_unlock(#{lock_key})")
      end
    end
  end
end
