class CommandRun < ApplicationRecord
  belongs_to :account, default: -> { Current.account }

  validates :command, presence: true

  delegate :started_at, :finished_at, :duration, to: :server_action
end
