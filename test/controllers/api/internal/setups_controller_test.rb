require "test_helper"

class Api::Internal::SetupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @setup_token = "abc123456"
    @valid_params = {
      server: {
        name: "test.example.com",
        public_ip: "127.0.0.1",
        cpu_type: "arm64"
      },
      user: {
        email: "bobby.tables@example.com"
      }
    }
    @headers = {Authorization: "Bearer #{@setup_token}"}
    ENV["ACCOUNT_SETUP_TOKEN"] = @setup_token
  end

  describe "#create" do
    test "returns a valid first run url" do
      Account.destroy_all
      User.destroy_all

      assert_no_difference ["Project.count", "App.count", "Domain.count", "Service.count", "EnvVariable.count", "ServiceLink.count", "ServerAction.count"] do
        assert_difference ["Account.count", "Server.count", "User.count"], 1 do
          post api_internal_setups_url, params: @valid_params, headers: @headers
        end
      end

      assert_response :success

      user_signed_id = json_response["first_run_url"].split("/").last
      user = User.find_by_token_for!(:first_run, user_signed_id)

      assert_equal "bobby.tables@example.com", user.email

      account = user.accounts.last
      server = account.servers.last

      assert_equal "test.example.com", server.name
      assert_equal "127.0.0.1", server.public_ip
      assert_equal "arm64", server.cpu_type
    end

    test "first run url expires after one day" do
      Account.destroy_all
      User.destroy_all

      freeze_time do
        post api_internal_setups_url, params: @valid_params, headers: @headers
        assert_response :success
        token = json_response["first_run_url"].split("/").last
        assert User.find_by_token_for(:first_run, token)

        travel 1.day + 1.second
        assert_nil User.find_by_token_for(:first_run, token)
      end
    end

    test "imports installed watergun resources when installation params are provided" do
      Account.destroy_all
      User.destroy_all

      dsn = "postgres://watergun:secret@dokku-postgres-watergun-db:5432/watergun-db"
      params = @valid_params.deep_merge(
        installation: {
          project: {
            name: "Watergun"
          },
          app: {
            name: "Watergun",
            dokku_id: "watergun",
            builder: "dockerfile"
          },
          domain: {
            hostname: "watergun.example.com",
            ssl_enabled: true
          },
          service: {
            name: "Watergun DB",
            dokku_id: "watergun-db",
            service_type: "postgres",
            version: "18",
            dsn:
          },
          service_link: {
            env_name: "DATABASE_URL"
          }
        }
      )

      assert_no_difference "ServerAction.count" do
        assert_difference ["Account.count", "Server.count", "User.count", "Project.count", "App.count", "Domain.count", "Service.count", "EnvVariable.count", "ServiceLink.count"], 1 do
          post api_internal_setups_url, params:, headers: @headers
        end
      end

      assert_response :success

      account = Account.find_by!(name: "Default")
      project = account.projects.find_by!(name: "Watergun")
      app = project.apps.find_by!(dokku_id: "watergun")
      domain = app.domains.find_by!(hostname: "watergun.example.com")
      service = project.services.find_by!(dokku_id: "watergun-db")
      env_variable = app.env_variables.find_by!(name: "DATABASE_URL")
      service_link = ServiceLink.find_by!(app:, service:)

      assert_equal "Watergun", app.name
      assert_equal "dockerfile", app.builder
      assert_equal "active", app.status
      assert_predicate app.deployed_at, :present?

      assert_equal "active", domain.status
      assert_predicate domain, :is_default?
      assert_predicate domain, :ssl_enabled?

      assert_equal "Watergun DB", service.name
      assert_equal "postgres", service.service_type
      assert_equal "active", service.status
      assert_equal "18", service.version
      assert_equal dsn, service.dsn
      assert_predicate service.deployed_at, :present?

      assert_equal dsn, env_variable.value
      assert_predicate env_variable, :internal?
      assert_equal "synced", env_variable.status
      assert_predicate env_variable.synced_at, :present?
      assert_equal env_variable, service_link.env_variable
      assert_equal "active", service_link.status
    end

    test "returns an error if the setup token is invalid" do
      post api_internal_setups_url, params: @valid_params, headers: {Authorization: "Bearer invalid"}

      assert_response :unauthorized
      assert_equal "Invalid setup token", json_response["error"]
    end

    test "returns an error if an account already exists" do
      post api_internal_setups_url, params: @valid_params, headers: @headers

      assert_response :unprocessable_content
      assert_equal "An account already exists", json_response["error"]
    end

    test "returns an error if the server params are invalid" do
      Account.destroy_all
      User.destroy_all

      params = @valid_params.merge(user: {email: "invalid"})
      post api_internal_setups_url, params:, headers: @headers

      assert_response :unprocessable_content
      assert_equal "Validation failed: Email is invalid", json_response["error"]
    end
  end
end
