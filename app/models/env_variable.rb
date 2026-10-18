class EnvVariable < ApplicationRecord
  include Discard::Model

  RESERVED_PREFIX = "DOKKU_"
  NAME_REGEX = /\A[a-zA-Z_][a-zA-Z0-9_]*\z/

  encrypts :value

  belongs_to :account, default: -> { app.account }
  belongs_to :app, touch: true

  has_one :service_link, dependent: :destroy

  enum :status, Enum[:pending, :syncing, :synced, :error], default: :pending

  scope :external, -> { where(internal: false) }
  scope :editable, -> { external.where.not("name LIKE ?", "#{RESERVED_PREFIX}%") }

  validates :name, presence: true
  validates :name, format: {with: NAME_REGEX}, allow_blank: true
  validates :name, uniqueness: {scope: :app_id, conditions: -> { undiscarded }}, allow_blank: true
  validates :value, presence: true, unless: -> { validation_context == :batch }
  validates :value, exclusion: {in: [nil]}, on: :batch

  delegate :project, to: :app

  def reserved?
    name.start_with?(RESERVED_PREFIX)
  end

  def editable?
    !internal? && !reserved? && !service_link
  end

  def to_h
    {name => value}
  end
end
