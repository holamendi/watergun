require "test_helper"

class App::CreateAppTest < ActiveSupport::TestCase
  describe "#save" do
    setup do
      @project = projects(:default)
      @account = @project.account
      @server = @project.server
      @create_app = App::CreateApp.new(
        project: @project,
        name: "Test App",
        repo: "holamendi/smol-roda",
        branch: "main",
        webhook_deploy: true
      )
    end

    test "succeeds with valid params" do
      VCR.use_cassette("github/valid_repo_and_branch") do
        assert @create_app.save
      end

      app = @create_app.app
      assert app.persisted?
      assert_equal @account, app.account
      assert_equal @server, app.server
      assert_equal "Test App", app.name
      assert_equal "test-app", app.dokku_id

      github_repo = app.github_repo
      assert github_repo.persisted?
      assert_equal "holamendi/smol-roda", github_repo.repo
      assert_equal "main", github_repo.branch
      assert_equal true, github_repo.webhook_deploy
      assert_equal false, github_repo.private

      assert_server_action_scheduled(
        ServerActions::CreateApp,
        server: @server,
        target: app,
        payload: {
          dokku_app_id: "test-app"
        }
      )
    end

    test "fails when the repo does not exist" do
      @create_app.repo = "holamendi/not-a-repo-123"

      VCR.use_cassette("github/invalid_repo") do
        refute @create_app.save
        assert_equal "does not exist", @create_app.errors.messages[:repo].first
      end
    end

    test "fails when the branch does not exist" do
      @create_app.branch = "not-a-branch-123"

      VCR.use_cassette("github/invalid_branch") do
        refute @create_app.save
        assert_equal "does not exist", @create_app.errors.messages[:branch].first
      end
    end
  end
end
