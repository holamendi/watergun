class ServerAction < ApplicationRecord
  include BelongsToOrg
  include BelongsToMembership
  include BelongsToServer

  attr_accessor :ssh_session
  alias_method :ssh, :ssh_session

  belongs_to :actionable, polymorphic: true, optional: true

  has_one :log, class_name: "ServerActionLog", dependent: :destroy

  enum status: {
    pending: "pending",
    running: "running",
    success: "success",
    failure: "failure"
  }, _default: "pending"

  attribute :source, :string, default: "web"

  scope :pending_or_running, -> { where(status: %w[pending running]) }

  def self.perform_later!(actionable, **)
    create!(actionable:, **).perform_later
  end

  def perform_and_log
    raise "server action must implement #perform" unless respond_to?(:perform, true)

    self.running_at = Time.current
    running!

    result = server.ssh_session do |ssh_session|
      with(ssh_session:) { perform }
    end

    create_log!(org:, ssh_commands: result.commands)

    self.completed_at = result.completed_at
    result.success? ? success! : failure!
  rescue => e
    self.completed_at = Time.current
    failure!

    raise e if Rails.env.local?
  end

  def concurrency_key
    actionable
  end

  def perform_later
    PerformServerActionJob.perform_later(self)
  end

  def completed?
    completed_at.present?
  end

  def duration
    return if running_at.blank? || completed_at.blank?

    completed_at - running_at
  end
end
