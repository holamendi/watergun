require "test_helper"

class ServiceTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:watergun)
    @server = servers(:x86)
    @project = projects(:calendar)
    @service = services(:postgres)
  end
  test "account defaults to Current.account" do
    Current.set(account: @account, server: @server) do
      service = Service.new
      service.validate
      assert_equal @account, service.account
    end
  end

  test "server defaults to Current.server" do
    Current.set(server: @server) do
      service = Service.new
      service.validate
      assert_equal @server, service.server
    end
  end

  test "name defaults to titleized service type" do
    service = Service.create!(service_type: "postgres", account: @account, server: @server, project: @project)
    assert_equal "Postgres", service.name

    service_2 = Service.create!(service_type: "postgres", account: @account, server: @server, project: @project)
    assert_match(/Postgres-[0-9a-f]{4}/i, service_2.name)
  end

  test "dokku_id is set on create" do
    service = Service.create!(name: "Postgres DB", service_type: "postgres", account: @account, server: @server, project: @project)
    assert_equal "postgres-db", service.dokku_id

    service_2 = Service.create!(name: "Postgres DB", service_type: "postgres", account: @account, server: @server, project: @project)
    assert_match(/postgres-db-[0-9a-f]{4}/i, service_2.dokku_id)
  end
end
