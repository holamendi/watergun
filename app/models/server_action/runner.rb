class ServerAction::Runner
  def initialize(run)
    @run = run
  end

  def self.report(error, run_id, phase: "execution")
    sanitized = StandardError.new("Server action #{phase} failed (#{error.class.name})")
    Honeybadger.notify(sanitized, context: {server_action_run_id: run_id})
  rescue
    Rails.logger.error("Server action telemetry unavailable")
  end

  def call
    # Keep the same resource scope as the queue even after its finite lease
    # expires. Resolve legacy server-scoped runs to their app/service as well.
    resource_key = @run.target ? ServerAction::ResourceKey.for(@run.target) : @run.resource_key
    lock_key = Digest::SHA256.digest(resource_key).unpack1("q>")
    ServerActionRun.connection_pool.with_connection do |connection|
      connection.execute("SELECT pg_advisory_lock(#{lock_key})")
      primary = nil
      begin
        Current.set(executing_server_action: @run) { perform_claimed }
      rescue => error
        primary = error
        raise
      ensure
        begin
          connection.execute("SELECT pg_advisory_unlock(#{lock_key})")
        rescue => unlock_error
          self.class.report(unlock_error, @run.id, phase: "resource lock release")
          raise unlock_error unless primary
        end
      end
    end
  end

  private

  def perform_claimed
    claimed = ServerActionRun.where(id: @run.id, status: :queued).update_all(status: :running, running_at: Time.current)
    return @run unless claimed == 1

    primary = nil
    status = :success
    validated = false
    begin
      @run.reload
      if @run.api_token_id
        ApiToken.transaction do
          token = ApiToken.lock.find(@run.api_token_id)
          ServerAction::Accept.authorize!(token, ServerAction::Accept::SCOPES.fetch(@run.action_key))
          raise ServerAction::Accept::Error, "unauthorized" unless token.account_id == @run.account_id && token.user_id == @run.user_id
        end
      end
      @action = ServerAction::Registry.build(@run)
      @run.target&.reload
      @action.validate!
      validated = true
      @logs = ServerAction::LogPersistence.new(@run, @action)
      @run.server.ssh_session do |session|
        @logs.start(session)
        @action.execute!(session)
        unless @run.update_columns(remote_completed_at: Time.current)
          raise ActiveRecord::RecordNotSaved, "Remote completion was not recorded"
        end
        @action.succeeded!
      end
    rescue Ssh::CommandExecutionError => error
      primary = error
      status = :failure
    rescue => error
      primary = error
      status = :error
    ensure
      @logs&.stop
    end

    if primary && validated
      begin
        @action.failed!
      rescue => secondary
        self.class.report(secondary, @run.id, phase: "reconciliation")
      end
    end

    begin
      @logs&.persist
    rescue => log_error
      self.class.report(log_error, @run.id, phase: "log persistence") if primary
      primary ||= log_error
      status = :error unless status == :failure
    end

    begin
      # update_columns mutates and clears the attribute before executing SQL.
      # Only a fresh persisted marker can release uncertain-work exclusion.
      @run.reload
      @run.update!(status: status, finished_at: Time.current,
        outcome_uncertain: validated && status == :error && !@run.remote_completed_at,
        dispatch_pending_at: nil, public_error_code: public_error(primary, status),
        failure_message: (status == :error) ? "Server action failed (#{primary.class.name})" : nil)
    rescue => write_error
      self.class.report(write_error, @run.id, phase: "final persistence")
      raise(primary || write_error)
    end
    if status == :error
      self.class.report(primary, @run.id)
      raise primary
    end
    @run
  end

  def public_error(primary, status)
    return if @run.remote_completed_at || status == :success
    return "authorization_failed" if primary.is_a?(ServerAction::Accept::Error)
    (status == :failure) ? "remote_failed" : "outcome_unknown"
  end
end
