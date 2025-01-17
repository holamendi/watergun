class Container < ApplicationRecord
  belongs_to :account, default: -> { server.account }
  belongs_to :server

  belongs_to :containerizable, polymorphic: true
  has_many :checks, class_name: "ContainerCheck", dependent: :delete_all

  scope :checked_within, ->(from:, to: Time.current) { joins(:checks).where(container_checks: {timestamp: from..to}).distinct }

  enum :status, %w[running stopped].index_by(&:itself), default: :running

  def dokku_process_type
    name.split(".").second_to_last
  end

  def self.stop_all
    update_all(status: "stopped", stopped_at: Time.current)
  end
end
