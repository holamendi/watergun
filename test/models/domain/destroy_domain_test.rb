require "test_helper"

class Domain::DestroyDomainTest < ActiveSupport::TestCase
  setup do
    @domain = domains(:domain_test_secondary)
    @app = @domain.app
    @server = @app.server
  end

  test "discards the domain" do
    Domain::DestroyDomain.new(@domain).destroy

    assert @domain.reload.discarded?
  end

  test "schedules DestroyDomain server action" do
    Domain::DestroyDomain.new(@domain).destroy

    assert_server_action_scheduled(
      ServerActions::DestroyDomain,
      server: @server,
      target: @domain
    )
  end
end
