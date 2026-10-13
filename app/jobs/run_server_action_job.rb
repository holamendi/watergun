class RunServerActionJob < ApplicationJob
  class ExecutionError < StandardError; end
  self.enqueue_after_transaction_commit = false
  limits_concurrency to: 1, key: ->(_run_id, resource_key) { resource_key }, duration: 30.minutes

  def perform(run_id, resource_key)
    run = ServerActionRun.find(run_id)
    raise ArgumentError, "Resource key mismatch" unless run.resource_key == resource_key
    begin
      ServerAction::Runner.new(run).call
    rescue
      raise ExecutionError, "Server action execution failed", cause: nil
    end
  end
end
