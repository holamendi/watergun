class ServerActionRun < ApplicationRecord
  belongs_to :account
  belongs_to :server
  belongs_to :user, optional: true
  belongs_to :target, polymorphic: true, optional: true
  has_one :log, class_name: "ServerActionLog", dependent: :destroy

  serialize :payload, coder: JSON
  encrypts :payload, support_unencrypted_data: false

  enum :source, Enum[:web, :api_v1]
  enum :status, Enum[:queued, :running, :success, :failure, :cancelled, :error], default: :queued
  attribute :source, :string, default: -> { Current.source.presence || "web" }
  scope :queued_or_running, -> { where(status: %i[queued running]) }
  scope :unscheduled, -> { where(status: :queued, enqueued_at: nil) }
  validates :action_key, :resource_key, presence: true

  broadcasts_to ->(run) { [run.account, :server_actions] },
    partial: "server_actions/server_action", target: "server_actions", inserts_by: :prepend

  def to_partial_path = "server_actions/server_action"

  PUBLIC_KINDS = {"apps.create" => "app.create", "apps.destroy" => "app.delete",
                  "apps.restart" => "app.restart", "apps.update_env" => "app.env", "apps.deploy" => "deployment.create"}.freeze

  PUBLIC_ERRORS = %w[dispatch_failed remote_failed outcome_unknown authorization_failed].freeze

  def public_operation
    public_status = if (remote_completed_at && finished_at) || success?
      "succeeded"
    elsif queued? || running?
      status
    else
      "failed"
    end
    code = public_error_code || "remote_failed"
    code = "outcome_unknown" unless PUBLIC_ERRORS.include?(code)
    {id: id, kind: PUBLIC_KINDS.fetch(action_key), status: public_status,
     app_id: operation_app_id, deployment_id: operation_deployment_id, request_id: request_id,
     created_at: created_at.utc.iso8601(6), started_at: running_at&.utc&.iso8601(6),
     finished_at: finished_at&.utc&.iso8601(6),
     error: (public_status == "failed") ? {code: code, message: code.humanize} : nil}
  end

  def filtered_payload
    ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters + [:set]).filter(payload || {})
  end

  def slug = action_key
  def finished? = finished_at.present?
  def duration = running_at && finished_at && finished_at - running_at

  def cancel!
    with_lock do
      return false unless queued?
      update!(status: :cancelled, finished_at: Time.current)
    end
    true
  end
end
