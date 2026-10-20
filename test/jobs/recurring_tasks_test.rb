require "test_helper"

class RecurringTasksTest < ActiveSupport::TestCase
  setup do
    @tasks = ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/recurring.yml")).fetch("production")
  end

  test "trims server checks" do
    task = SolidQueue::RecurringTask.from_configuration("trim_server_checks", **@tasks.fetch("trim_server_checks").symbolize_keys)

    assert_predicate task, :valid?
    assert_equal "ServerCheck.trim_in_batches", task.command
  end
end
