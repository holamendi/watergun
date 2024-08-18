class Service::Destroyer
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
    ServerAction::DestroyService.run_later!(@service)
  end

  def destroy_service_links
    @service.service_links.each do |service_link|
      ServiceLink::Destroyer.new(service_link).destroy
    end
  end
end
