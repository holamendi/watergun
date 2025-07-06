require "test_helper"

class ServiceTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:default)
    @server = servers(:amd)
    @project = projects(:default)
    @service = services(:postgres)
  end

  test "dokku_id is set on create" do
    service = Service.create!(name: "Postgres DB", service_type: "postgres", server: @server, project: @project)
    assert_equal "postgres-db", service.dokku_id

    service_2 = Service.create!(name: "Postgres DB", service_type: "postgres", server: @server, project: @project)
    assert_match(/postgres-db-[0-9a-f]{4}/i, service_2.dokku_id)
  end
end
