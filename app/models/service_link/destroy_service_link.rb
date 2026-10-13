class ServiceLink::DestroyServiceLink
  def initialize(service_link)
    @service_link = service_link
  end

  def destroy
    @service_link.discard
    ServerAction::Enqueue.call(action: ServerActions::UnlinkService, target: @service_link)
  end
end
