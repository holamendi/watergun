class Api::V1::OperationResource < Api::ApplicationResource
  root_key :operation, :operations

  attributes :id, :request_id

  attribute :kind do |run|
    ServerActionRun::PUBLIC_KINDS.fetch(run.action_key)
  end

  attribute :status, &:public_status
  attribute :app_id, &:operation_app_id
  attribute :deployment_id, &:operation_deployment_id

  attribute :created_at do |run|
    run.created_at.utc.iso8601(6)
  end

  attribute :started_at do |run|
    run.running_at&.utc&.iso8601(6)
  end

  attribute :finished_at do |run|
    run.finished_at&.utc&.iso8601(6)
  end

  attribute :error do |run|
    if run.public_status == "failed"
      code = run.repair_required? ? "repair_required" : (run.public_error_code || "remote_failed")
      code = "outcome_unknown" unless ServerActionRun::PUBLIC_ERRORS.include?(code)
      {code: code, message: code.humanize}
    end
  end
end
