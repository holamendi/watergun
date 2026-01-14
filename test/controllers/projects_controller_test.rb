require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:default)
    @server = @account.servers.first
    @project = projects(:default)

    sign_in users(:bobby)
  end

  describe "#show" do
    test "renders the project name" do
      get project_path(@project)

      assert_response :success
      assert_select "h1", text: @project.name
    end

    test "renders back link to projects" do
      get project_path(@project)

      assert_response :success
      assert_select "a[href='#{projects_path}']", text: /Projects/
    end

    test "lists apps with links" do
      app = apps(:smol_roda)
      get project_path(@project)

      assert_response :success
      assert_select "a[href='#{project_app_deployments_path(@project, app)}']", text: /#{app.name}/
    end

    test "lists services with links" do
      service = services(:postgres)
      get project_path(@project)

      assert_response :success
      assert_select "a[href='#{project_service_path(@project, service)}']", text: /#{service.name}/
    end

    test "shows add app action" do
      get project_path(@project)

      assert_response :success
      assert_select "a[href='#{new_project_app_path(@project)}']", text: /App/
    end

    test "shows add service action" do
      get project_path(@project)

      assert_response :success
      assert_select "a[href='#{new_project_service_path(@project)}']", text: /Service/
    end
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
