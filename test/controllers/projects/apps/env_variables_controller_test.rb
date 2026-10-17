require "test_helper"

class Projects::Apps::EnvVariablesControllerTest < ActionDispatch::IntegrationTest
  include SshTestHelper

  setup do
    @project = projects(:default)
    @app = apps(:smol_roda)
    @user = users(:bobby)

    sign_in @user
  end

  test "variable row menu preserves reveal copy lazy edit and confirmed deletion" do
    @app.env_variables.create!(name: "UI_EXAMPLE", value: "example-only")
    get project_app_env_variables_path(@project, @app)
    assert_select "[data-controller='row-actions'] button[aria-haspopup='menu']"
    assert_select "button[role='menuitem'][data-action='secret-field#toggle']", text: "Reveal value"
    assert_select "button[role='menuitem'][data-action='clipboard#copy']", text: "Copy value"
    assert_select "a[role='menuitem'][data-turbo-frame='env_variable_form']", text: "Edit Variable"
    assert_select "a[role='menuitem'][data-turbo-method='delete'][data-turbo-confirm]", text: "Delete Variable"
    assert_select "[data-clipboard-target='status'][role='status']"
  end

  test "name-only update queues replacement and removal of the old name" do
    variable = @app.env_variables.create!(name: "OLD_NAME", value: "example-only")

    assert_difference -> { ServerActionRun.where(action_key: "apps.update_env").count }, 1 do
      patch project_app_env_variable_path(@project, @app, variable),
        params: {env_variable: {name: "NEW_NAME", value: variable.value}},
        as: :turbo_stream
    end

    assert_response :success
    assert_equal "NEW_NAME", variable.reload.name
    action = ServerActionRun.where(action_key: "apps.update_env").order(:id).last
    assert_equal @app, action.target
    assert_equal @app.server, action.server
    assert_equal({"NEW_NAME" => "example-only"}, action.payload["set"])
    assert_equal ["OLD_NAME"], action.payload["unset"]
  end

  test "name and value update executes the replacement before removing the old name" do
    variable = @app.env_variables.create!(name: "OLD_NAME", value: "example-only")

    assert_difference -> { ServerActionRun.where(action_key: "apps.update_env").count }, 1 do
      patch project_app_env_variable_path(@project, @app, variable),
        params: {env_variable: {name: "NEW_NAME", value: "new-example"}},
        as: :turbo_stream
    end

    assert_response :success
    assert_equal "new-example", variable.reload.value
    action = ServerActionRun.where(action_key: "apps.update_env").order(:id).last
    assert_equal({"NEW_NAME" => "new-example"}, action.payload["set"])
    assert_equal ["OLD_NAME"], action.payload["unset"]

    require_relative "../../../../app/models/ssh/session"
    set_command = Dokku::Config::SetCommand.new(app: @app.dokku_id, env: {"NEW_NAME" => "new-example"}).cmd
    unset_command = "dokku config:unset #{@app.dokku_id} OLD_NAME --no-restart"
    mock_ssh_session(
      host: @app.server.public_ip,
      user: SshKey::USER,
      port: @app.server.ssh_port,
      private_key: @app.server.ssh_key.private_key,
      ordered: true,
      commands: [{cmd: set_command}, {cmd: unset_command}]
    )

    assert_difference -> { ServerActionRun.where(action_key: "apps.pull_env").count }, 1 do
      RunServerActionJob.perform_now(action.reload.id, action.reload.resource_key)
    end

    assert_predicate action.reload, :success?
    redacted_set_command = Dokku::Config::SetCommand.new(app: @app.dokku_id, env: {"NEW_NAME" => "new-example"}).redacted_cmd
    assert_equal [redacted_set_command, unset_command], action.log.ssh_commands.map { |command| command.fetch("cmd") }
    refute action.payload["restart"]
  end

  test "value-only update does not unset the unchanged name" do
    variable = @app.env_variables.create!(name: "SAME_NAME", value: "example-only")

    assert_difference -> { ServerActionRun.where(action_key: "apps.update_env").count }, 1 do
      patch project_app_env_variable_path(@project, @app, variable),
        params: {env_variable: {name: variable.name, value: "new-example"}},
        as: :turbo_stream
    end

    assert_response :success
    action = ServerActionRun.where(action_key: "apps.update_env").order(:id).last
    assert_equal({"SAME_NAME" => "new-example"}, action.payload["set"])
    assert_empty action.payload["unset"]
  end

  test "unchanged variable does not queue a remote update" do
    variable = @app.env_variables.create!(name: "SAME_NAME", value: "example-only")

    assert_no_difference "ServerActionRun.count" do
      patch project_app_env_variable_path(@project, @app, variable),
        params: {env_variable: {name: variable.name, value: variable.value}},
        as: :turbo_stream
    end

    assert_response :success
  end

  test "enqueue validation failure does not save an environment edit" do
    variable = @app.env_variables.create!(name: "BEFORE", value: "before-only")
    ServerAction::Enqueue.stubs(:build).raises(ArgumentError, "Rejected action")

    assert_no_difference "ServerActionRun.count" do
      assert_raises(ArgumentError) do
        patch project_app_env_variable_path(@project, @app, variable),
          params: {env_variable: {name: "AFTER", value: "after-only"}}, as: :turbo_stream
      end
    end

    assert_equal "BEFORE", variable.reload.name
    assert_equal "before-only", variable.value
  end

  test "invalid rename leaves the persisted variable and remote queue unchanged" do
    variable = @app.env_variables.create!(name: "OLD_NAME", value: "example-only")

    assert_no_difference "ServerActionRun.count" do
      patch project_app_env_variable_path(@project, @app, variable),
        params: {env_variable: {name: "INVALID-NAME", value: "new-example"}},
        as: :turbo_stream
    end

    assert_response :unprocessable_content
    assert_equal "OLD_NAME", variable.reload.name
    assert_equal "example-only", variable.value
  end

  test "create and delete use the shared environment lifecycle" do
    post project_app_env_variables_path(@project, @app),
      params: {env_variable: {name: "SHARED_EXAMPLE", value: "example-only"}}, as: :turbo_stream
    assert_response :created
    variable = @app.env_variables.find_by!(name: "SHARED_EXAMPLE")
    run = @app.server_action_runs.where(action_key: "apps.update_env").order(:id).last
    assert_equal({"SHARED_EXAMPLE" => "example-only"}, run.payload["set"])

    delete project_app_env_variable_path(@project, @app, variable), as: :turbo_stream
    assert_response :success
    assert variable.reload.discarded?
    run = @app.server_action_runs.where(action_key: "apps.update_env").order(:id).last
    assert_equal ["SHARED_EXAMPLE"], run.payload["unset"]
  end

  test "invalid creation renders record errors and retains the submitted form" do
    assert_no_difference ["EnvVariable.count", "ServerActionRun.count"] do
      post project_app_env_variables_path(@project, @app),
        params: {env_variable: {name: "INVALID-NAME", value: ""}}, as: :turbo_stream
    end
    assert_response :unprocessable_content
    assert_select "input[name='env_variable[name]'][value='INVALID-NAME']"
    assert_includes response.body, "is invalid"
    assert_includes response.body, "can&#39;t be blank"
  end

  test "enqueue validation failure rolls back environment creation and deletion" do
    variable = @app.env_variables.create!(name: "EXISTING", value: "example-only")
    ServerAction::Enqueue.stubs(:build).raises(ArgumentError, "Rejected action")
    assert_no_difference ["EnvVariable.count", "ServerActionRun.count"] do
      assert_raises(ArgumentError) do
        post project_app_env_variables_path(@project, @app),
          params: {env_variable: {name: "NEW_EXAMPLE", value: "new-only"}}, as: :turbo_stream
      end
      assert_raises(ArgumentError) do
        delete project_app_env_variable_path(@project, @app, variable), as: :turbo_stream
      end
    end
    assert variable.reload.kept?
  end

  test "duplicate rename leaves both variables and remote queue unchanged" do
    variable = @app.env_variables.create!(name: "OLD_NAME", value: "example-only")
    existing = @app.env_variables.create!(name: "EXISTING_NAME", value: "existing-example")

    assert_no_difference "ServerActionRun.count" do
      patch project_app_env_variable_path(@project, @app, variable),
        params: {env_variable: {name: existing.name, value: "new-example"}},
        as: :turbo_stream
    end

    assert_response :unprocessable_content
    assert_equal "OLD_NAME", variable.reload.name
    assert_equal "example-only", variable.value
    assert_equal "existing-example", existing.reload.value
  end

  describe "#index" do
    test "renders variables page with settings sidebar" do
      get project_app_env_variables_path(@project, @app)

      assert_response :success
      assert_select "h1", text: "Environment Variables"
      assert_select "nav[aria-label='Settings navigation']"
      assert_select "[data-ui-component='page-header']"
      assert_select "a[data-ui-component='button'][data-turbo-frame='env_variable_form']"
      assert_select "#env_variables_section"
      assert_select "[data-ui-component='empty-state']"
    end
  end
end
