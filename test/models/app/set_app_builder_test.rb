require "test_helper"

class App::SetAppBuilderTest < ActiveSupport::TestCase
  setup { apps(:smol_roda).update!(builder: "herokuish") }

  test "sets the builder and registered run through a plain service" do
    app = apps(:smol_roda)
    assert defined?(App::SetAppBuilder), "Builder configuration needs a service object"
    refute App::SetAppBuilder < ApplicationRecord
    assert_difference "ServerActionRun.count", 1 do
      assert App::SetAppBuilder.new(app: app, builder: "dockerfile").save
    end
    assert_equal "dockerfile", app.reload.builder
    run = app.server_action_runs.order(:id).last.reload
    assert_equal "apps.set_builder", run.action_key
    assert_equal "dockerfile", run.payload["builder"]
  end

  test "builder enqueue rejection rolls back the persisted builder" do
    app = apps(:smol_roda)
    original = app.builder
    ServerAction::Enqueue.stubs(:build).raises(ArgumentError, "Rejected action")
    assert_no_difference "ServerActionRun.count" do
      assert_raises(ArgumentError) { App::SetAppBuilder.new(app: app, builder: "dockerfile").save }
    end
    assert_equal original, app.reload.builder
  end

  test "builder service preserves account member and availability guards" do
    app = apps(:smol_roda)
    original = app.builder
    Current.account = accounts(:other)
    assert_raises(ArgumentError) { App::SetAppBuilder.new(app: app, builder: "dockerfile").save }
    Current.reset
    outsider = User.create!(email: "builder-outsider@example.test", password: "test-only-password")
    outsider.memberships.create!(account: accounts(:other))
    Current.user = outsider
    Current.account = app.account
    assert_raises(ArgumentError) { App::SetAppBuilder.new(app: app, builder: "dockerfile").save }
    Current.reset
    app.discard!
    assert_raises(ArgumentError) { App::SetAppBuilder.new(app: app, builder: "dockerfile").save }
    assert_equal original, app.reload.builder
  ensure
    Current.reset
  end

  test "unsupported builder values do not persist or enqueue" do
    app = apps(:smol_roda)
    original = app.builder
    assert_no_difference "ServerActionRun.count" do
      assert_raises(ArgumentError) { App::SetAppBuilder.new(app: app, builder: "unsupported").save }
    end
    assert_equal original, app.reload.builder
  end
end
