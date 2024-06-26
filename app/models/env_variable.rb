class EnvVariable < ApplicationRecord
  include Discard::Model

  belongs_to :account, default: -> { Current.account }
  belongs_to :app, touch: true

  str_enum :status, [:pending, :syncing, :synced, :error], default: :pending

  validates :key, presence: true, uniqueness: {scope: :app_id, conditions: -> { undiscarded }}
  validates :value, presence: true

  delegate :project, to: :app

  def to_h
    {key => value}
  end
end
