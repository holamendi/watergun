require "test_helper"

class ServerActionResourceKeyTest < ActiveSupport::TestCase
  test "app child targets use their parent app key" do
    app = apps(:domain_test_app)
    key = "app:#{app.id}"
    assert_equal key, ServerAction::ResourceKey.for(app)
    assert_equal key, ServerAction::ResourceKey.for(domains(:domain_test_secondary))
    assert_equal key, ServerAction::ResourceKey.for(app.storage_mounts.new)
    assert_equal "app:#{apps(:smol_roda).id}", ServerAction::ResourceKey.for(deployments(:pending_deployment))
  end

  test "service links use their service key rather than their app key" do
    service = services(:postgres)
    link = ServiceLink.new(service: service, app: apps(:domain_test_app))
    assert_equal "service:#{service.id}", ServerAction::ResourceKey.for(service)
    assert_equal ServerAction::ResourceKey.for(service), ServerAction::ResourceKey.for(link)
    refute_equal ServerAction::ResourceKey.for(link.app), ServerAction::ResourceKey.for(link)
  end

  test "project operations retain their own resource scope" do
    project = projects(:default)
    assert_equal "project:#{project.id}", ServerAction::ResourceKey.for(project)
  end

  test "resource types with matching IDs do not collide" do
    refute_equal ServerAction::ResourceKey.for(App.new(id: 1)), ServerAction::ResourceKey.for(Service.new(id: 1))
  end
end
