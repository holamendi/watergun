require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:default)
    @server = @account.servers.first

    sign_in users(:bobby)
  end

  describe "#create" do
    test "creates a project for the current account" do
      assert_difference -> { Project.count }, 1 do
        post projects_url, params: {project: {name: "Test"}}
      end

      project = Project.last

      assert_equal project.server, @server
      assert_equal project.account, @account
      assert_equal project.name, "Test"
      assert_redirected_to project_url(project)
    end

    test "does not create a project when the name is not present" do
      assert_no_difference -> { Project.count } do
        post projects_url, params: {project: {name: ""}}
      end

      assert_response :unprocessable_content
    end

    test "does not create a project when the name exists" do
      project = projects(:default)

      assert_no_difference -> { Project.count } do
        post projects_url, params: {project: {name: project.name}}
      end

      assert_response :unprocessable_content
    end
  end
end
