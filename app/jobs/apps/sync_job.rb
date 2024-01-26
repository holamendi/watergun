module Apps
  class SyncJob < ApplicationJob
    queue_as :default

    def perform(app)
      Apps::Sync.new(app:).call
    end
  end
end
