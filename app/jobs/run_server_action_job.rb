class RunServerActionJob < ApplicationJob
  limits_concurrency to: 1, key: ->(server_action) { server_action.concurrency_key }, duration: 30.minutes

  def perform(server_action)
    return if server_action.running_at?
    return server_action.cancelled! if server_action.preceding_action&.failure?

    account, server, user = server_action.values_at(:account, :server, :user)

    Current.set(account:, server:, user:) do
      server_action.running!

      session = server.ssh_session do |ssh_session|
        server_action.with(ssh_session:) { server_action.send(:run) }
      rescue Ssh::CommandExecutionError
      end

      server_action.create_log!(ssh_commands: session.commands)
      server_action.status = session.status
      server_action
    rescue => e
      Honeybadger.notify(e, context: {server_action_id: server_action.id})
      server_action.status = :error
      raise if Rails.env.development?

      server_action
    ensure
      server_action.finished_at = Time.current
      server_action.save!
    end
  end
end
