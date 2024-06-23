class EnvVariable < ApplicationRecord
  belongs_to :org, default: -> { Current.org }
  belongs_to :app

  validates :key, presence: true, uniqueness: {scope: :app_id, conditions: -> { undiscarded }}
  validates :value, presence: true

  after_create_commit -> { ServerActions::Set.perform_later!(self) }
  after_update_commit -> { broadcast_refresh_to(app) }
  after_discard -> { ServerActions::DestroyEnvVariable.perform_later!(self) }
  after_destroy -> { ServerActions::DestroyEnvVariable.perform_later!(self) }, unless: :discarded?

  delegate :project, to: :app
end
