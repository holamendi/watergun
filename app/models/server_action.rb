class ServerAction < ApplicationRecord
  include Broadcast

  belongs_to :account, default: -> { Current.account }
  belongs_to :server, default: -> { Current.server }
  belongs_to :user, default: -> { Current.user }
  belongs_to :actionable, polymorphic: true, optional: true
  belongs_to :preceding_action, class_name: "ServerAction", optional: true, foreign_key: "preceding_server_action_id"

  has_one :log, class_name: "ServerActionLog", dependent: :destroy

  str_enum :status, %i[queued running success failure cancelled error], default: :queued
  str_enum :source, [:web, :api_v1]

  attribute :source, :string, default: -> { Current.source }

  scope :queued_or_running, -> { where(status: %i[queued running]) }

  attr_accessor :ssh_session
  alias_method :ssh, :ssh_session

  def run_now(force: false)
    RunServerActionJob.perform_now(self, force:)
  end

  def run_later(wait: 1.second, force: false)
    RunServerActionJob.set(wait:).perform_later(self, force:)
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

    def run_later!(actionable, depends_on: nil, **)
      action = create!(actionable:, preceding_action: depends_on, **)
      action.run_later
      action
    end
  end
end
