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
    # Solid Queue's lease is finite. A session-level advisory lock also protects
    # overlapping server mutations when a queue concurrency lease expires.
    ServerActionRun.connection_pool.with_connection do |connection|
      connection.execute("SELECT pg_advisory_lock(1464288082, #{@run.server_id.to_i})")
      primary = nil
      begin
        perform_claimed
      rescue => error
        primary = error
        raise
      ensure
        begin
          connection.execute("SELECT pg_advisory_unlock(1464288082, #{@run.server_id.to_i})")
        rescue => unlock_error
          self.class.report(unlock_error, @run.id, phase: "server lock release")
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
      @action = ServerAction::Registry.build(@run)
      @run.target&.reload
      @action.validate!
      validated = true
      @logs = ServerAction::LogPersistence.new(@run, @action)
      @run.server.ssh_session do |session|
        @logs.start(session)
        @action.execute!(session)
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
      @run.update!(status: status, finished_at: Time.current,
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
end
