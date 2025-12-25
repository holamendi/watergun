require "test_helper"
require "ostruct"

class Github::InstallationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @github_app = github_apps(:default)
    @account = @github_app.account
    @user = users(:bobby)
    sign_in @user
  end

  test "callback creates installation from GitHub API" do
    installation_id = 987654321

    # Mock the Octokit API response
    installation_response = OpenStruct.new(
      id: installation_id,
      account: OpenStruct.new(login: "holamendi")
    )

    # Mock the api_client method on the Github::App instance
    Github::App.any_instance.stubs(:api_client).returns(
      stub(installation: installation_response)
    )

    assert_difference -> { Github::Installation.count }, 1 do
      get callback_github_installations_url, params: {installation_id: installation_id}
    end

    installation = Github::Installation.last
    assert_equal @account, installation.account
    assert_equal @github_app, installation.github_app
    assert_equal installation_id, installation.installation_id
    assert_equal "holamendi", installation.login

    assert_redirected_to account_path
    assert_equal "Github account connected", flash[:notice]
  end

  test "callback fails with invalid installation_id" do
    installation_id = 999999999

    # Mock the api_client to raise NotFound
    mock_client = stub
    mock_client.stubs(:installation).raises(Octokit::NotFound.new)
    Github::App.any_instance.stubs(:api_client).returns(mock_client)

    assert_no_difference -> { Github::Installation.count } do
      get callback_github_installations_url, params: {installation_id: installation_id}
    end

    assert_redirected_to account_path
    assert_equal "Invalid installation id", flash[:error]
  end

  test "destroy uninstalls GitHub App and deletes installation" do
    installation = @github_app.installations.create!(
      account: @account,
      installation_id: 123456,
      login: "testuser"
    )

    # Mock the delete_installation API call
    mock_client = stub
    mock_client.stubs(:delete_installation).returns(true)
    Github::App.any_instance.stubs(:api_client).returns(mock_client)

    assert_difference -> { Github::Installation.count }, -1 do
      delete github_installation_url(installation)
    end

    assert_redirected_to account_path
    assert_equal "Github App uninstalled", flash[:notice]
  end
end
