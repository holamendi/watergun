class CommandRun < ApplicationRecord
  belongs_to :account

  validates :command, presence: true

  delegate :started_at, :finished_at, :duration, to: :server_action_run
end
