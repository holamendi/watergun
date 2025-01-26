require "test_helper"

class AppTest < ActiveSupport::TestCase
  setup do
    @project = projects(:default)
    @account = @project.account
    @server = @project.server
  end

  test "dokku_id is set on create" do
    app = App.create!(name: "Rails Is Omakase", account: @account, server: @server, project: @project)
    assert_equal "rails-is-omakase", app.dokku_id
  end
end
