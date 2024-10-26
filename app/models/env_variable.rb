class EnvVariable < ApplicationRecord
  include Discard::Model

  encrypts :value

  RESERVED_PREFIX = "DOKKU"

  belongs_to :account, default: -> { Current.account }
  belongs_to :app, touch: true

  has_one :service_link, dependent: :destroy

  enum :status, %w[pending syncing synced error].index_by(&:itself), default: :pending

  validates :name, presence: true, uniqueness: {scope: :app_id, conditions: -> { undiscarded }}
  validates :value, presence: true

  scope :sorted_by_name, -> { order(name: :asc) }
  scope :not_reserved, -> { where.not("name LIKE ?", "#{RESERVED_PREFIX}%") }
  scope :not_internal, -> { where(internal: false) }

  delegate :project, to: :app

  def reserved?
    name.start_with?(RESERVED_PREFIX)
  end

  def to_h
    {name => value}
  end
end
