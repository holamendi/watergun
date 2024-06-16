class ServerAction < ApplicationRecord
  include Memery
  include ServerActions::Performer

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
end
