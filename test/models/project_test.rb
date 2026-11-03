require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "server must belong to the project account" do
    project = accounts(:default).projects.new(name: "Foreign server", server: servers(:other_server))

    assert_not project.valid?
    assert project.errors[:server].any?
  end
end
