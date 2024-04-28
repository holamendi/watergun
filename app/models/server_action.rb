class ServerAction < ApplicationRecord
  include BelongsToOrg
  include BelongsToServer

  attr_accessor :ssh_session
  alias_method :ssh, :ssh_session

  belongs_to :actionable, polymorphic: true, optional: true

  has_one :log, class_name: "ServerActionLog", dependent: :destroy

  enum status: {
    queued: "queued",
    running: "running",
    success: "success",
    failure: "failure"
  }, _default: "queued"

  attribute :source, :string, default: "web"

  scope :queued_or_running, -> { where(status: %i[queued running]) }

  after_save_commit -> { broadcast_refresh_to(org, :server_actions) }

  def self.perform_later!(actionable, **)
    create!(actionable:, **).perform_later
  end

  def perform_later
    PerformServerActionJob.perform_later(self)
  end

  def fail!(message = nil)
    raise(ServerActionFailure, message)
  end

  def perform_action
    raise "server action must implement #perform" unless respond_to?(:perform, true)

    self.running_at = Time.current
    running!

    result = server.ssh_session do |ssh_session|
      with(ssh_session:) { perform }
    end

    create_log!(ssh_commands: result.commands)

    self.status = if result.success?
      :success
    else
      :failure
    end
  rescue ServerActionFailure => e
    self.status = :failure
    self.failure_message = e.message
  rescue => e
    self.status = :failure
    self.failure_message = e.detailed_message
    raise e if Rails.env.local?
  ensure
    self.finished_at = Time.current
    save!
  end

  def concurrency_key
    actionable
  end

  def finished?
    finished_at.present?
  end

  def duration
    return unless finished?

    finished_at - running_at
  end

  class ServerActionFailure < StandardError; end
end
