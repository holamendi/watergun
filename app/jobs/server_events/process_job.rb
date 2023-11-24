module ServerEvents
  class ProcessJob < ApplicationJob
    queue_as :default

    def perform(server_event)
      klass = "ServerEvents::#{server_event.event_type.camelize}".constantize
      klass.new(server_event).call
    end
  end
end
