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
  validates :value, presence: true

  delegate :project, to: :app

  def reserved?
    name.start_with?(RESERVED_PREFIX)
  end

  def to_h
    {name => value}
  end

  def save_and_sync
    return false unless valid?
    validate_sync_context!
    unless editable_for_sync?
      errors.add(:base, "Environment variable is not editable")
      return false
    end

    transaction do
      save!
      if saved_change_to_name? || saved_change_to_value?
        unset = (saved_change_to_name? && name_before_last_save) ? [name_before_last_save] : []
        ServerAction::Enqueue.call(action: "apps.update_env", target: app, payload: {set: to_h, unset:})
      end
    end
    true
  end

  def discard_and_sync!
    validate_sync_context!
    raise ArgumentError, "Environment variable is not editable" unless editable_for_sync?

    transaction do
      discard!
      ServerAction::Enqueue.call(action: "apps.update_env", target: app, payload: {unset: [name]})
    end
  end

  private

  def validate_sync_context!
    ServerAction::TargetValidation.app_context!(app)
    raise ArgumentError, "Environment variable ownership mismatch" unless account_id == app.account_id
    raise ArgumentError, "Environment variable is discarded" if discarded?
  end

  def editable_for_sync?
    !internal? && !internal_in_database && !service_link &&
      !reserved? && !name_in_database&.start_with?(RESERVED_PREFIX)
  end
end
