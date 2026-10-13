require "test_helper"

class App::DestroyAppTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "queued deletion keeps app visible until remote success" do
    app = apps(:domain_test_app)

    assert_enqueued_with(job: RunServerActionJob) do
      action = App::DestroyApp.new(app).destroy
      assert_equal app, action.target
      assert action.queued?
    end

    assert app.reload.kept?
    assert app.active?
  end
end
