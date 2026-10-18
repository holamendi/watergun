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

  # Deliberately narrow: the confirmed remote deletion can only need local row
  # destruction. No SSH, arbitrary success hook replay, or generic success flag.
  # Other actions require inspected, action-specific repair, not blind retries.
  def self.repair_delete!(run)
    resource = run.target ? ServerAction::ResourceKey.for(run.target) : run.resource_key
    lock_key = Digest::SHA256.digest(resource).unpack1("q>")
    ServerActionRun.connection_pool.with_connection do |connection|
      raise ServerAction::Conflict::Error unless connection.select_value("SELECT pg_try_advisory_lock(#{lock_key})")

      begin
        run.with_lock do
          raise ArgumentError, "Only a confirmed remote app deletion can be repaired" unless run.action_key == "apps.destroy" && run.remote_completed_at
          next run if run.finalized_at

          raise ArgumentError, "App deletion target is required" unless run.target_type == "App"

          app = App.find_by(id: run.target_id)
          if app
            ServerAction::Conflict.with_app_lock(app) do
              run.target = app
              ServerAction::TargetValidation.call(run, type: App, required: %w[dokku_app_id])
              app.destroy!
            end
          end
          run.update!(status: :success, finalized_at: Time.current, finished_at: Time.current,
            public_error_code: nil, outcome_uncertain: false, dispatch_pending_at: nil)
          run
        end
      ensure
        connection.execute("SELECT pg_advisory_unlock(#{lock_key})")
      end
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
            finalized = run.finalized_at.present?
            run.update!(status: finalized ? :success : :error, finished_at: Time.current,
              public_error_code: if finalized
                                   nil
                                 else
                                   (run.remote_completed_at ? "repair_required" : "outcome_unknown")
                                 end, outcome_uncertain: !run.remote_completed_at,
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
