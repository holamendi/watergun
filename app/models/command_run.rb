class CommandRun < ApplicationRecord
  has_paper_trail on: %i[create]

  belongs_to :org, default: -> { Current.org }

  validates :command, presence: true

  delegate :started_at, :finished_at, :duration, to: :server_action
end
