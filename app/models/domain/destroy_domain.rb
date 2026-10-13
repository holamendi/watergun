class Domain::DestroyDomain
  def initialize(domain)
    @domain = domain
  end

  def destroy
    @domain.discard
    ServerAction::Enqueue.call(action: ServerActions::DestroyDomain, target: @domain)
  end
end
