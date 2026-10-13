class Domain::DestroyDomain
  def initialize(domain)
    @domain = domain
  end

  def destroy
    @domain.discard
    ServerAction::Enqueue.call(action: "apps.remove_domain", target: @domain)
  end
end
