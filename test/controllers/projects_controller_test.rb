require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:default)
    @server = @account.servers.first
    @project = projects(:default)

    sign_in users(:bobby)
  end

  describe "#index" do
    test "shows projects for the current server only" do
      post select_server_path(servers(:amd))

      get projects_path

      assert_response :success
      assert_select "a", text: /Default Project/
      assert_select "a", text: /Arm Project/, count: 0
    end

    test "switching server shows that server's projects" do
      post select_server_path(servers(:arm))

      get projects_path

      assert_response :success
      assert_select "a", text: /Arm Project/
      assert_select "a", text: /Default Project/, count: 0
    end

    test "renders ui page header and modal trigger" do
      get projects_path

      assert_response :success
      assert_select "[data-ui-component='page-header']"
      assert_select "button[data-ui-component='modal-trigger']", text: "New Project"
    end
  end

  describe "#show" do
    test "renders the project name" do
      get project_path(@project)

      assert_response :success
      assert_select "h1", text: @project.name
    end

    test "renders project title" do
      get project_path(@project)

      assert_response :success
      assert_select "h1", text: @project.name
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
      assert_select "a[href='#{new_project_app_path(@project)}']"
    end

    test "shows add service action" do
      get project_path(@project)

      assert_response :success
      assert_select "a[href='#{new_project_service_path(@project)}']"
    end

    test "renders ui page header shell" do
      get project_path(@project)

      assert_response :success
      assert_select "[data-ui-component='page-header']"
    end

    test "renders empty states with shared component for empty project" do
      empty_project = @account.projects.create!(name: "Empty Project", server: @server)

      get project_path(empty_project)

      assert_response :success
      assert_select "[data-ui-component='empty-state']", count: 2
    end
  end

  describe "#update" do
    test "rejects a foreign server" do
      patch project_path(@project), params: {project: {server_id: servers(:other_server).id}}

      assert_response :success
      assert_equal servers(:amd), @project.reload.server
    end

    test "rejects moving a populated project to another server" do
      patch project_path(@project), params: {project: {server_id: servers(:arm).id}}

      assert_response :success
      assert_equal servers(:amd), @project.reload.server
    end
  end

  describe "#destroy" do
    test "does not expose another account project" do
      foreign = accounts(:other).projects.create!(name: "Other", server: servers(:other_server))

      assert_no_difference -> { ServerActionRun.count } do
        delete project_path(foreign)
      end
      assert_response :not_found
      assert foreign.reload.kept?
    end
  end

  describe "#create" do
    test "rejects a server from another account" do
      assert_no_difference -> { Project.count } do
        post projects_url, params: {project: {name: "Foreign", server_id: servers(:other_server).id}}, as: :turbo_stream
      end

      assert_response :success
      assert_includes response.body, "must belong to the project account"
    end

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
        post projects_url, params: {project: {name: ""}}, as: :turbo_stream
      end

      assert_response :success
      assert_includes response.body, "turbo-stream"
    end

    test "does not create a project when the name exists" do
      project = projects(:default)

      assert_no_difference -> { Project.count } do
        post projects_url, params: {project: {name: project.name}}, as: :turbo_stream
      end

      assert_response :success
      assert_includes response.body, "turbo-stream"
    end
  end
end
