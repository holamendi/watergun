class CommandRun < ApplicationRecord
  has_paper_trail on: %i[create]

  include BelongsToOrg

  validates :command, presence: true

  delegate :started_at, :finished_at, :duration, to: :server_action
end
