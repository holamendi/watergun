require "test_helper"

class DokkuImportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :bobby
    @server = accounts(:default).servers.order(:id).first
  end

  test "create creates an import project and enqueues an import action" do
    assert_difference -> { Project.dokku_imports.count }, 1 do
      assert_difference -> { ServerActions::ImportDokkuProject.count }, 1 do
        assert_enqueued_with(job: RunServerActionJob) do
          post dokku_import_url
        end
      end
    end

    action = ServerActions::ImportDokkuProject.last
    project = action.project

    assert_redirected_to server_action_path(action)
    assert_equal @server, action.server
    assert_equal @server, project.server
    assert_equal "Dokku Import", project.name
    assert_predicate project, :dokku_import
    refute_predicate action, :include_watergun
  end

  test "create reuses an existing marked import project" do
    project = @server.projects.create!(account: @server.account, name: "Dokku Import", dokku_import: true)

    assert_no_difference -> { Project.count } do
      assert_difference -> { ServerActions::ImportDokkuProject.count }, 1 do
        post dokku_import_url
      end
    end

    assert_equal project, ServerActions::ImportDokkuProject.last.project
  end

  test "create redirects to an existing queued import action" do
    project = @server.projects.create!(account: @server.account, name: "Dokku Import", dokku_import: true)
    action = ServerActions::ImportDokkuProject.create!(server: @server, actionable: project)

    assert_no_difference -> { ServerActions::ImportDokkuProject.count } do
      post dokku_import_url
    end

    assert_redirected_to server_action_path(action)
  end

  test "create stores include_watergun when requested" do
    post dokku_import_url, params: {include_watergun: "1"}

    assert_predicate ServerActions::ImportDokkuProject.last, :include_watergun
  end
end
