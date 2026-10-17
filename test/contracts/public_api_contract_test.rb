require "test_helper"
require "json_schemer"
require "open3"

class PublicApiContractTest < ActiveSupport::TestCase
  CONTRACT_PATH = Rails.root.join("docs/api/openapi.yml")

  test "the versioned contract exists and is a valid OpenAPI document" do
    assert_path_exists CONTRACT_PATH
    document = JSONSchemer.openapi(YAML.safe_load_file(CONTRACT_PATH, aliases: true), regexp_resolver: "ecma")
    assert document.valid?, document.validate.map { |error| error["data_pointer"] }.join(", ")
  end

  test "every first release route declares bearer scopes and mutation acceptance" do
    assert_path_exists CONTRACT_PATH
    contract = YAML.safe_load_file(CONTRACT_PATH, aliases: true)
    expected = {
      "/api/v1/projects" => %w[get],
      "/api/v1/projects/{id}/apps" => %w[get post],
      "/api/v1/apps" => %w[get],
      "/api/v1/apps/{id}" => %w[get delete],
      "/api/v1/apps/{id}/ping" => %w[get],
      "/api/v1/apps/{id}/env" => %w[put],
      "/api/v1/apps/{app_id}/deployments" => %w[get post],
      "/api/v1/apps/{app_id}/deployments/{id}" => %w[get],
      "/api/v1/apps/{app_id}/deployments/{id}/logs" => %w[get],
      "/api/v1/apps/{id}/restarts" => %w[post],
      "/api/v1/operations/{id}" => %w[get]
    }
    expected.each do |path, methods|
      methods.each do |method|
        operation = contract.fetch("paths").fetch(path).fetch(method)
        assert_equal [{"bearerAuth" => []}], operation.fetch("security"), "#{method} #{path}"
        assert_includes %w[apps:read apps:write deployments:write env:write operations:read logs:read], operation.fetch("x-required-scope")
        responses = operation.fetch("responses")
        %w[401 403 404 429].each { |status| assert responses.key?(status), "#{method} #{path}: #{status}" }
        next if method == "get"

        assert responses.key?("202")
        %w[Location Retry-After X-Request-ID].each { |header| assert responses.fetch("202").fetch("headers").key?(header) }
        assert operation.fetch("parameters").any? { |parameter| parameter["$ref"] == "#/components/parameters/IdempotencyKey" }
      end
    end
  end

  test "the executable schema checker fails closed without printing secret data" do
    checker = Rails.root.join("script/check-api-contract")
    assert_path_exists checker
    stdout, stderr, status = Open3.capture3("bundle", "exec", "ruby", checker.to_s, "EnvWrite", stdin_data: '{"mode":"merge","values":{"SECRET":"do-not-print-sentinel"},"command":"bad"}')
    assert_not status.success?
    assert_not_includes stdout + stderr, "do-not-print-sentinel"
    assert_includes stderr, "invalid"
  end

  test "the runnable workflow never retries a failed mutation or prints response secrets" do
    example = Rails.root.join("script/api-workflow")
    assert_path_exists example
    load example
    transport = lambda do |request|
      assert_equal "POST", request.method
      assert_equal "/api/v1/projects/1/apps", request.path
      assert request["Idempotency-Key"].present?
      Struct.new(:code, :body).new("422", '{"secret":"do-not-print-sentinel"}')
    end
    output = StringIO.new
    client = WatergunApiWorkflow.new(base_url: "https://example.test", token: "test-only", transport: transport, output: output)
    error = assert_raises(WatergunApiWorkflow::Failure) { client.run(project_id: 1, name: "test", repo: "owner/repo", branch: "main", env: {}) }
    assert_equal "HTTP 422", error.message
    assert_nil error.cause
    assert_includes output.string, "run_key="
  end

  test "the runnable workflow exercises the complete target sequence with a stable retry key" do
    load Rails.root.join("script/api-workflow")
    document = JSONSchemer.openapi(YAML.safe_load_file(CONTRACT_PATH, aliases: true), regexp_resolver: "ecma")
    calls = []
    deployment_keys = []
    transport = lambda do |request|
      calls << [request.method, request.path]
      response = Net::HTTPResponse.new("1.1", (request.method == "GET") ? "200" : "202", "test")
      if request.path.start_with?("/api/v1/operations/")
        body = {"operation" => {"status" => "succeeded"}}
      elsif request.path.include?("/logs?")
        body = {"logs" => [], "next_cursor" => nil, "complete" => true, "expires_at" => "2026-11-17T00:00:00Z"}
      elsif request.method == "GET"
        body = {"app" => {"url" => "https://disposable.example.test"}}
      else
        schema, id = case request.method
        when "PUT" then ["EnvWrite", 2]
        when "DELETE" then [nil, 5]
        else
          if request.path.end_with?("/restarts")
            [nil, 4]
          elsif request.path.end_with?("/deployments")
            deployment_keys << request["Idempotency-Key"]
            ["DeploymentCreate", 3]
          else
            ["AppCreate", 1]
          end
        end
        assert document.schema(schema).valid?(JSON.parse(request.body)) if schema
        body = {"operation" => {"id" => id, "app_id" => 42, "deployment_id" => (101 if id == 3)}}
        response["Location"] = "/api/v1/operations/#{id}"
      end
      response.body = JSON.generate(body)
      response.instance_variable_set(:@read, true)
      response
    end
    output = StringIO.new
    client = WatergunApiWorkflow.new(base_url: "https://example.test", token: "test-only", transport: transport, output: output)
    assert_equal 42, client.run(project_id: 1, name: "test", repo: "owner/repo", branch: "main", env: {"SECRET" => "do-not-print-sentinel"})
    assert_equal 2, deployment_keys.size
    assert_equal 1, deployment_keys.uniq.size
    assert_equal ["POST", "PUT", "POST", "POST", "POST", "DELETE"], calls.map(&:first).reject { |method| method == "GET" }
    assert_includes calls, ["GET", "/api/v1/apps/42/deployments/101/logs?after=0&limit=100"]
    assert_not_includes output.string, "do-not-print-sentinel"
    assert_not_includes output.string, "test-only"
  end

  test "incomplete log pages are polled before deletion" do
    client, calls = workflow_with_logs do |poll|
      {"logs" => [], "next_cursor" => nil, "complete" => poll > 1}
    end
    assert_equal 42, client.run(project_id: 1, name: "test", repo: "owner/repo", branch: "main", env: {})
    assert_equal 2, calls.count { |method, path| method == "GET" && path.include?("/logs?") }
    assert_includes calls, ["DELETE", "/api/v1/apps/42"]
  end

  test "incomplete log polling exhaustion preserves the app" do
    client, calls = workflow_with_logs { |_| {"logs" => [], "next_cursor" => nil, "complete" => false} }
    error = assert_raises(WatergunApiWorkflow::Failure) { client.run(project_id: 1, name: "test", repo: "owner/repo", branch: "main", env: {}) }
    assert_includes error.message, "logs"
    assert_not_includes calls, ["DELETE", "/api/v1/apps/42"]
  end

  test "log pagination exhaustion preserves the app" do
    client, calls = workflow_with_logs { |poll| {"logs" => [], "next_cursor" => poll, "complete" => true} }
    error = assert_raises(WatergunApiWorkflow::Failure) { client.run(project_id: 1, name: "test", repo: "owner/repo", branch: "main", env: {}) }
    assert_includes error.message, "logs"
    assert_not_includes calls, ["DELETE", "/api/v1/apps/42"]
  end

  private

  def workflow_with_logs
    load Rails.root.join("script/api-workflow")
    calls = []
    polls = 0
    transport = lambda do |request|
      calls << [request.method, request.path]
      response = Net::HTTPResponse.new("1.1", (request.method == "GET") ? "200" : "202", "test")
      body = if request.path.include?("/logs?")
        yield(polls += 1)
      elsif request.path.start_with?("/api/v1/operations/")
        {"operation" => {"status" => "succeeded"}}
      elsif request.method == "GET"
        {"app" => {"url" => "https://disposable.example.test"}}
      else
        response["Location"] = "/api/v1/operations/1"
        {"operation" => {"id" => 1, "app_id" => 42, "deployment_id" => 101}}
      end
      response.body = JSON.generate(body)
      response.instance_variable_set(:@read, true)
      response
    end
    [WatergunApiWorkflow.new(base_url: "https://example.test", token: "test-only", transport: transport, output: StringIO.new, sleeper: ->(_) {}), calls]
  end
end
