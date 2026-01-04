class ServerCheck < ApplicationRecord
  belongs_to :account, default: -> { server.account }
  belongs_to :server

  def self.trim_in_batches(older_than: 1.day.ago)
    ServerCheck.where(timestamp: ..older_than).in_batches(&:delete_all)
  end
end
