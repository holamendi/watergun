class RunServerActionJob < ApplicationJob
  limits_concurrency to: 1, key: ->(server_action) { server_action.concurrency_key }, duration: 30.minutes

  def perform(server_action)
    return server_action.cancelled! if server_action.preceding_action&.failure?

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
    server_action.failure_message = e.detailed_message
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
