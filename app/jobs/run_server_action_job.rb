class RunServerActionJob < ApplicationJob
  limits_concurrency to: 1, key: ->(server_action) { server_action.concurrency_key }, duration: 30.minutes

  def perform(server_action)
    if server_action.preceding_action&.failure?
      server_action.cancelled!
      return server_action
    end

    server_action.running!

    session = server_action.server.ssh_session do |ssh_session|
      server_action.with(ssh_session:) { server_action.send(:run) }
    rescue Ssh::CommandExecutionError
    end

    server_action.create_log!(ssh_commands: session.commands)
    server_action.status = session.status
  rescue => e
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
    server_action.finished_at = Time.current
    server_action.save!
  end
end
