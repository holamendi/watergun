class PerformServerActionJob < ApplicationJob
  limits_concurrency to: 1, key: ->(server_action) { server_action.concurrency_key }, duration: 30.minutes

  def perform(server_action)
    return unless server_action.queued?
    return server_action.cancelled! if server_action.preceding_action&.failure?

    Current.set(org: server_action.org, server: server_action.server) do
      server_action.perform_action
    end
  end
end
