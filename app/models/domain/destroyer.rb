class Domain::Destroyer
  def initialize(domain)
    @domain = domain
  end

  def destroy
    @domain.discard
    ServerAction::DestroyDomain.run_later!(@domain)
  end
end
