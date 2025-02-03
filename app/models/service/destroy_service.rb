class Service::DestroyService
  def initialize(service)
    @service = service
  end

  def destroy
    ApplicationRecord.transaction do
      destroy_service_links
      destroy_service
    end
  end

  private

  def destroy_service
    @service.discard
    ServerActions::DestroyService.run_later!(@service.server, @service)
  end

  def destroy_service_links
    @service.service_links.each do |service_link|
      ServiceLink::DestroyServiceLink.new(service_link).destroy
    end
  end
end
