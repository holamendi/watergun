module Apps
  class Destroy < ApplicationCommand
    attribute :app

    def call
      unlink_and_discard_services!
      discard_app!
    end

    private

    def discard_app!
      app.discard!
      ServerActions::DestroyApp.perform_later!(app)
    end

    def unlink_and_discard_services!
      app.service_links.kept.includes(:service).each do |service_link|
        service_link.discard!
        unlink_action = ServerActions::UnlinkService.perform_later!(service_link)
        service_link.service.discard!
        ServerActions::DestroyService.perform_later!(service_link.service, depends_on: unlink_action)
      end
    end
  end
end
