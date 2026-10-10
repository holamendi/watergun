class ServerAction < ApplicationRecord
  belongs_to :account, default: -> { server.account }
  belongs_to :actionable, polymorphic: true, optional: true
  belongs_to :server
  belongs_to :user, default: -> { Current.user }, optional: true

  has_one :log, class_name: "ServerActionLog", dependent: :destroy

  enum :source, Enum[:web, :api_v1]
  enum :status, Enum[:queued, :running, :success, :failure, :cancelled, :error], default: :queued

  attribute :source, :string, default: -> { Current.source.presence || "web" }

  scope :queued_or_running, -> { where(status: %i[queued running]) }

  class_attribute :persist_logs_interval, default: nil

  attr_accessor :ssh_session
  alias_method :ssh, :ssh_session

  delegate :execute, :execute!, to: :ssh_session

  # Called after logs are persisted to DB (when persist_logs_interval is set)
  # Subclasses can override to handle persisted data (e.g., broadcast updates)
  # @param commands [Array<Ssh::Command>] current state of all commands
  def on_logs_persisted(commands:)
    # Default: do nothing
  end

  broadcasts_to ->(server_action) { [server_action.account, :server_actions] },
    partial: "server_actions/server_action",
    inserts_by: :prepend

  def on_failure
    # Subclasses can reconcile their target when connection setup fails.
  end

  def run_now
    RunServerActionJob.perform_now(self)
  end

  def run_later(wait: 0.seconds)
    RunServerActionJob.set(wait:).perform_later(self)
  end

  def running!(at = Time.current)
    update!(status: :running, running_at: at)
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

  def slug
    self.class.slug
  end

  class << self
    def actionable(type)
      alias_method :"#{type.to_s.underscore}", :actionable

      validates :actionable_type, inclusion: {in: [type.to_s]}
    end

    def slug
      self::SLUG
    end

    def model_name
      ActiveModel::Name.new(ServerAction)
    end

    def run_now!(server, actionable, **)
      action = create!(server:, actionable:, **)
      action.run_now
      action
    end

    def run_later!(server, actionable, **)
      action = create!(server:, actionable:, **)
      action.run_later
      action
    end
  end
end
