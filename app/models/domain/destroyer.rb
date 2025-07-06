class Domain::Destroyer
  def initialize(domain)
    @domain = domain
  end

  def destroy
    @domain.discard
    ServerActions::DestroyDomain.run_later!(@domain)
  end
end
