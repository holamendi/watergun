class ContainerCheck < ApplicationRecord
  belongs_to :account, default: -> { container.account }

  belongs_to :container

  def self.trim_in_batches(older_than: 1.day.ago)
    ContainerCheck.where(timestamp: ..older_than).in_batches(&:delete_all)
  end
end
