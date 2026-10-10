class RunServerActionJob < ApplicationJob
  limits_concurrency to: 1, key: ->(server_action) { server_action.concurrency_key }, duration: 30.minutes

  def perform(server_action)
    server_action.running!

    # Set up periodic log persistence if configured
    if server_action.persist_logs_interval
      server_action.create_log!(ssh_commands: [])
      setup_log_persistence(server_action)
    end

    session = server_action.server.ssh_session do |ssh_session|
      server_action.with(ssh_session:) { server_action.send(:run) }
    rescue Ssh::CommandExecutionError
    ensure
      stop_log_persistence
    end

    # Final save of logs
    if server_action.log.present?
      server_action.log.update!(ssh_commands: session.commands)
      server_action.on_logs_persisted(commands: session.commands)
    else
      server_action.create_log!(ssh_commands: session.commands)
    end
    server_action.status = session.status
  rescue => e
    server_action.on_failure
    Honeybadger.notify(e, context: {server_action_id: server_action.id})
    server_action.status = :error
    server_action.failure_message = <<~ERROR
      Error: #{e.class}
      Message: #{e.message}

      Backtrace:
      #{e.backtrace.first(10).map { |line| "  #{line}" }.join("\n")}
      #{"\n  ... and #{e.backtrace.size - 10} more lines" if e.backtrace.size > 10}
    ERROR
    raise if Rails.env.local?

    server_action
  else
    server_action.failure_message = nil
    server_action
  ensure
    stop_log_persistence
    server_action.finished_at = Time.current
    server_action.save!
  end

  private

  def setup_log_persistence(server_action)
    @persisting_action = server_action
    @persist_timer_running = true

    @persist_timer = Thread.new do
      while @persist_timer_running
        sleep server_action.persist_logs_interval
        persist_logs if @persist_timer_running
      end
    end
  end

  def stop_log_persistence
    return unless @persist_timer

    @persist_timer_running = false
    @persist_timer.kill
    @persist_timer = nil

    # Final persist
    persist_logs
  end

  def persist_logs
    return unless @persisting_action

    session = @persisting_action.ssh_session
    return unless session

    # Save current state to DB
    @persisting_action.log&.update!(ssh_commands: session.commands)

    # Notify the action
    @persisting_action.on_logs_persisted(commands: session.commands)
  rescue => e
    Rails.logger.error("Failed to persist logs: #{e.message}")
  end
end
