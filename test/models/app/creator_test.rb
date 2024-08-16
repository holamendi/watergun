require "test_helper"

class App::CreatorTest < ActiveSupport::TestCase
  setup do
    Current.account = accounts(:watergun)
    Current.server = servers(:x86)

    @creator = App::Creator.new(
      project: projects(:calendar),
      name: "Smol Roda",
      repo: "holamendi/smol-roda",
      branch: "main",
      webhook_deploy: true
    )
  end

  test "succeeds with valid params" do
    VCR.use_cassette("github/valid_repo_and_branch") do
      @creator.create
      app = @creator.app
      github_repo = app.github_repo

      assert_equal "Smol Roda", app.name
      assert_equal "smol-roda", app.dokku_id
      assert_equal "holamendi/smol-roda", github_repo.repo
      assert_equal "main", github_repo.branch
      assert_equal true, github_repo.webhook_deploy
      assert_equal false, github_repo.private
    end
  end

  test "fails when the repo does not exist" do
    @creator.repo = "holamendi/not-a-repo-123"

    VCR.use_cassette("github/invalid_repo") do
      refute @creator.create
      assert_equal "does not exist", @creator.errors.messages[:repo].first
    end
  end

  test "fails when the branch does not exist" do
    @creator.branch = "not-a-branch-123"

    VCR.use_cassette("github/invalid_branch") do
      refute @creator.create
      assert_equal "does not exist", @creator.errors.messages[:branch].first
    end
  end
end
