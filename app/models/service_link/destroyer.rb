class ServiceLink::Destroyer
  def initialize(service_link)
    @service_link = service_link
  end

  def destroy
    @service_link.discard
    ServerActions::UnlinkService.run_later!(@service_link)
  end
end
