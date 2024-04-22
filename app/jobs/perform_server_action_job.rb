class PerformServerActionJob < ApplicationJob
  limits_concurrency to: 1, key: ->(server_action) { server_action.concurrency_key }, duration: 30.minutes

  def perform(server_action)
    return unless server_action.pending?

    server_action.update_columns(job_id:)
    server_action.perform_and_log
  end
end
