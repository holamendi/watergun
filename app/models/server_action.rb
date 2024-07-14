class ServerAction < ApplicationRecord
  include Broadcast
  include Runner

  belongs_to :account, default: -> { Current.account }
  belongs_to :server, default: -> { Current.server }
  belongs_to :actionable, polymorphic: true, optional: true
  belongs_to :preceding_action, class_name: "ServerAction", optional: true, foreign_key: "preceding_server_action_id"

  has_one :log, class_name: "ServerActionLog", dependent: :destroy

  str_enum :status, %i[queued running success failure cancelled error], default: :queued

  attribute :source, :string, default: "web"

  scope :queued_or_running, -> { where(status: %i[queued running]) }

  def slug
    self.class.slug
  end

  def concurrency_key
    actionable
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
  end
end
