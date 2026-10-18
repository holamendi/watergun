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

  PUBLIC_ERRORS = %w[dispatch_failed remote_failed outcome_unknown authorization_failed execution_failed repair_required].freeze

  def repair_required?
    remote_completed_at.present? && finalized_at.nil?
  end

  def public_status
    if queued? || running?
      status
    elsif !repair_required? && (success? || (finalized_at && finished_at))
      "succeeded"
    else
      "failed"
    end
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
