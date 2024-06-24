class EnvVariable < ApplicationRecord
  include Discard::Model

  belongs_to :org, default: -> { Current.org }
  belongs_to :app

  str_enum :status, [:pending, :synced, :error], default: :pending

  validates :key, presence: true, uniqueness: {scope: :app_id, conditions: -> { undiscarded }}
  validates :value, presence: true

  # after_create_commit -> { ServerActions::SetEnvVariables.perform_later!(self) }
  # after_update_commit -> { debugger }
  # after_discard -> { ServerActions::DestroyEnvVariable.perform_later!(self) }

  delegate :project, to: :app
end
