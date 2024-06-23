class CommandRun < ApplicationRecord
  belongs_to :org, default: -> { Current.org }

  validates :command, presence: true

  delegate :started_at, :finished_at, :duration, to: :server_action
end
