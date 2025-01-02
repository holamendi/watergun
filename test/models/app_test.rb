require "test_helper"

class AppTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:watergun)
    @server = servers(:x86)
    @project = projects(:calendar)
    @app = apps(:calendar)
  end

  test "account defaults to Current.account" do
    Current.set(account: @account) do
      app = App.new
      app.validate
      assert_equal @account, app.account
    end
  end

  test "server defaults to Current.server" do
    Current.set(server: @server) do
      app = App.new
      app.validate
      assert_equal @server, app.server
    end
  end

  test "dokku_id is set on create" do
    app = App.create!(name: "Rails Is Omakase", account: @account, server: @server, project: @project)
    assert_equal "rails-is-omakase", app.dokku_id
  end
end
