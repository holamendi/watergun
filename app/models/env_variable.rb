class EnvVariable < ApplicationRecord
  include Discard::Model

  RESERVED_PREFIX = "DOKKU"

  encrypts :value

  belongs_to :account, default: -> { Current.account }
  belongs_to :app, touch: true

  has_one :service_link, dependent: :destroy

  enum :status, %w[pending syncing synced error].index_by(&:itself), default: :pending

  scope :external, -> { where(internal: false) }
  scope :editable, -> { external.where.not("name LIKE ?", "#{RESERVED_PREFIX}%") }

  validates :name, presence: true, uniqueness: {scope: :app_id, conditions: -> { undiscarded }}
  validates :value, presence: true

  delegate :project, to: :app

  def reserved? = name.start_with?(RESERVED_PREFIX)

  def to_h = {name => value}
end
