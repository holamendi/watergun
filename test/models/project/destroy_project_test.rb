require "test_helper"

class Project::DestroyProjectTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "discards an owned project and queues destruction" do
    project = projects(:default)

    assert_enqueued_with(job: RunServerActionJob) do
      assert_difference -> { ServerAction.count }, 1 do
        Project::DestroyProject.new(project).destroy
      end
    end
    assert project.reload.discarded?
    action = ServerActions::DestroyProject.last
    assert_equal project, action.project
    assert_equal project.server, action.server
  end

  test "does not discard a project with a foreign server" do
    project = projects(:default)
    project.update_columns(server_id: servers(:other_server).id)

    assert_no_difference -> { ServerAction.count } do
      assert_raises(ActiveRecord::RecordInvalid) { Project::DestroyProject.new(project).destroy }
    end
    assert project.reload.kept?
  end
end
