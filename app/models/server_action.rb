class ServerAction < ApplicationRecord
  attr_accessor :ssh_session
  alias_method :ssh, :ssh_session

  belongs_to :account, default: -> { Current.account }
  belongs_to :server, default: -> { Current.server }
  belongs_to :actionable, polymorphic: true, optional: true
  belongs_to :preceding_action, class_name: "ServerAction", optional: true, foreign_key: "preceding_server_action_id"

  has_one :log, class_name: "ServerActionLog", dependent: :destroy

  str_enum :status, %i[queued running success failure cancelled error], default: :queued

  attribute :source, :string, default: "web"

  scope :queued_or_running, -> { where(status: %i[queued running]) }

  after_save_commit -> { broadcast_refresh_to(account, :server_actions) }

  def concurrency_key
    actionable
  end

  def run_action
    raise "server action must implement #run" unless respond_to?(:run, true)

    running!

    session = server.ssh_session do |ssh_session|
      with(ssh_session:) do
        run
      rescue Ssh::CommandExecutionError
      end
    end

    create_log!(ssh_commands: session.commands)
    self.status = session.status
    self
  rescue => e
    self.status = :error
    Honeybadger.notify(e, context: {server_action_id: id})
    raise if Rails.env.development?
    self
  ensure
    self.finished_at = Time.current
    save!
  end

  def running!(at = Time.current)
    update!(status: :running, running_at: at)
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

    def run_later!(actionable, depends_on: nil, **)
      action = create!(actionable:, preceding_action: depends_on, **)

      if defined?(Rails::Console)
        RunServerActionJob.perform_now(action)
      else
        RunServerActionJob.set(wait: 1.second).perform_later(action)
      end

      action
    end
  end
end
