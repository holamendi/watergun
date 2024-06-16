class ServerAction < ApplicationRecord
  include ServerActions::Performer

  attr_accessor :ssh_session
  alias_method :ssh, :ssh_session

  belongs_to :org, default: -> { Current.org }
  belongs_to :server, default: -> { Current.server }
  belongs_to :actionable, polymorphic: true, optional: true
  belongs_to :preceding_action, class_name: "ServerAction", optional: true, foreign_key: "preceding_server_action_id"

  has_one :log, class_name: "ServerActionLog", dependent: :destroy

  enum status: {
    queued: 0,
    running: 1,
    success: 2,
    failure: 3,
    cancelled: 4
  }, _default: :queued

  attribute :source, :string, default: "web"

  scope :queued_or_running, -> { where(status: %i[queued running]) }

  after_save_commit -> { broadcast_refresh_to(org, :server_actions) }

  def concurrency_key
    actionable
  end

  def perform_action
    raise "server action must implement #perform" unless respond_to?(:perform, true)

    self.running_at = Time.current
    running!

    session = server.ssh_session do |ssh_session|
      with(ssh_session:) do
        perform
      rescue Dokku::CommandExecutionError
      end
    end

    create_log!(ssh_commands: session.commands)
    self
  rescue => e
    self.status = :failure
    self.failure_message = e.detailed_message
    Honbeybadger.notify(e)
  else
    self.status = :success
  ensure
    self.finished_at = Time.current
    save!
  end

  def finished?
    finished_at.present?
  end

  def duration
    return unless finished?

    finished_at - running_at
  end

  def self.slug
    self::SLUG
  end

  def slug
    self.class.slug
  end

  def self.perform_later!(actionable, depends_on: nil, **)
    action = create!(actionable:, preceding_action: depends_on, **)
    PerformServerActionJob.perform_later(action)
    action
  end
end
