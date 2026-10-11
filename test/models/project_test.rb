require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "permits an empty project to move within its account" do
    project = accounts(:default).projects.create!(name: "Empty", server: servers(:amd))

    assert project.update(server: servers(:arm))
    assert_equal servers(:arm), project.reload.server
  end

  test "rejects foreign servers on direct model creation" do
    project = Project.new(name: "Foreign", account: accounts(:default), server: servers(:other_server))

    assert_not project.valid?
    assert_includes project.errors[:server], "must belong to the project account"
  end

  test "rejects reassignment with only discarded services" do
    project = projects(:default)
    project.apps.destroy_all
    project.services.each(&:discard!)

    assert_not project.update(server: servers(:arm))
    assert_equal servers(:amd), project.reload.server
  end

  test "allows renaming a populated project" do
    assert projects(:default).update(name: "Renamed")
  end

  test "rejects server reassignment when apps exist" do
    project = projects(:default)

    assert_not project.update(server: servers(:arm))
    assert_includes project.errors[:server], "cannot change while the project has resources"
    assert_equal servers(:amd), project.reload.server
  end
end
