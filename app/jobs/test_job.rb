class TestJob < ApplicationJob
  queue_as :default

  def perform(id)
    Rails.logger.info "TestJob: #{id}"
  end
end
