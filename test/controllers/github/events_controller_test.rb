require "test_helper"

class Github::EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @github_app = github_apps(:default)
    @installation = github_installations(:default)
    @webhook_secret = @github_app.webhook_secret
  end

  test "create receives push webhook and creates event" do
    payload = {
      ref: "refs/heads/main",
      after: "abc123def456",
      repository: {full_name: "holamendi/smol-roda"}
    }

    payload_json = payload.to_json
    signature = generate_github_webhook_signature(payload_json, @webhook_secret)

    assert_difference -> { Github::Event.count }, 1 do
      post github_events_url,
        params: payload_json,
        headers: github_webhook_headers("push", @github_app.app_id, signature).merge({
          "Content-Type" => "application/json"
        })
    end

    assert_response :ok

    event = Github::Event.last
    assert_equal @installation, event.installation
    assert_equal "push", event.event
    assert_equal "holamendi/smol-roda", event.payload.dig("repository", "full_name")
  end

  test "create enqueues ProcessEventJob" do
    payload = {
      ref: "refs/heads/main",
      after: "abc123def456",
      repository: {full_name: "holamendi/smol-roda"}
    }

    payload_json = payload.to_json
    signature = generate_github_webhook_signature(payload_json, @webhook_secret)

    assert_enqueued_with(job: Github::ProcessEventJob) do
      post github_events_url,
        params: payload_json,
        headers: github_webhook_headers("push", @github_app.app_id, signature).merge({
          "Content-Type" => "application/json"
        })
    end
  end

  test "create fails with invalid signature and returns 400" do
    payload_json = {ref: "refs/heads/main"}.to_json
    invalid_signature = "sha256=invalid_signature_abc123"

    assert_no_difference -> { Github::Event.count } do
      post github_events_url,
        params: payload_json,
        headers: github_webhook_headers("push", @github_app.app_id, invalid_signature).merge({
          "Content-Type" => "application/json"
        })
    end

    assert_response :bad_request
  end

  test "create handles installation.created event" do
    payload = {
      action: "created",
      installation: {id: 123456}
    }

    payload_json = payload.to_json
    signature = generate_github_webhook_signature(payload_json, @webhook_secret)

    assert_difference -> { Github::Event.count }, 1 do
      post github_events_url,
        params: payload_json,
        headers: github_webhook_headers("installation", @github_app.app_id, signature).merge({
          "Content-Type" => "application/json"
        })
    end

    event = Github::Event.last
    assert_equal "installation.created", event.slug
  end
end
