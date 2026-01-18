class Domain::DestroyDomain
  def initialize(domain)
    @domain = domain
  end

  def destroy
    @domain.discard
    ServerActions::DestroyDomain.run_later!(@domain.server, @domain)
  end
end
