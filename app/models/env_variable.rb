class EnvVariable < ApplicationRecord
  include Discard::Model

  belongs_to :org, default: -> { Current.org }
  belongs_to :app

  str_enum :status, [:pending, :synced, :error], default: :pending

  validates :key, presence: true, uniqueness: {scope: :app_id, conditions: -> { undiscarded }}
  validates :value, presence: true

  delegate :project, to: :app

  def to_h
    {key => value}
  end
end
