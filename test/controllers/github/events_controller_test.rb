require "test_helper"

class Github::EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:default)
    @github_app = github_apps(:default)
    @installation = github_installations(:default)
    @webhook_secret = @github_app.webhook_secret
  end

  test "routes a webhook to its payload installation ID" do
    selected = github_installations(:expired_token)
    payload_json = {
      ref: "refs/heads/main",
      installation: {id: selected.installation_id},
      repository: {full_name: "holamendi/smol-roda"}
    }.to_json
    signature = generate_github_webhook_signature(payload_json, @webhook_secret)

    assert_difference -> { selected.events.count }, 1 do
      assert_no_difference -> { @installation.events.count } do
        assert_enqueued_with(job: Github::ProcessEventJob) do
          post github_events_url(id: @account.id), params: payload_json,
            headers: github_webhook_headers("push", @github_app.app_id, signature).merge("Content-Type" => "application/json")
        end
      end
    end
    assert_response :ok
    assert_equal selected.account, Github::Event.last.account
  end

  test "rejects a missing installation ID even with an unidentified local installation" do
    @installation.update!(installation_id: nil)

    assert_no_difference -> { Github::Event.count } do
      assert_no_enqueued_jobs(only: Github::ProcessEventJob) do
        post_signed_event("push", {ref: "refs/heads/main"})
      end
    end
    assert_response :not_found
  end

  test "rejects an installation belonging to another account's GitHub app" do
    foreign_app = @github_app.dup
    foreign_app.account = accounts(:other)
    foreign_app.save!
    foreign_installation = Github::Installation.create!(
      account: accounts(:other), github_app: foreign_app, installation_id: 456789
    )

    assert_no_difference -> { Github::Event.count } do
      assert_no_enqueued_jobs(only: Github::ProcessEventJob) do
        post_signed_event("installation", {action: "deleted", installation: {id: foreign_installation.installation_id}})
      end
    end
    assert_response :not_found
    assert foreign_installation.reload.persisted?
    assert @installation.reload.persisted?
  end

  test "rejects an unknown installation ID without falling back" do
    assert_no_difference -> { Github::Event.count } do
      assert_no_enqueued_jobs(only: Github::ProcessEventJob) do
        post_signed_event("push", {installation: {id: 999999999}})
      end
    end
    assert_response :not_found
  end

  test "installation deletion destroys only the selected installation" do
    selected = github_installations(:expired_token)

    assert_difference -> { Github::Installation.count }, -1 do
      perform_enqueued_jobs(only: Github::ProcessEventJob) do
        post_signed_event("installation", {action: "deleted", installation: {id: selected.installation_id}})
      end
    end
    assert_response :ok
    assert_nil Github::Installation.find_by(id: selected.id)
    assert @installation.reload.persisted?
    assert_equal 0, Github::Event.where(github_installation_id: selected.id).count
  end

  test "create receives push webhook and creates event" do
    payload = {
      ref: "refs/heads/main",
      installation: {id: @installation.installation_id},
      after: "abc123def456",
      repository: {full_name: "holamendi/smol-roda"}
    }

    payload_json = payload.to_json
    signature = generate_github_webhook_signature(payload_json, @webhook_secret)

    assert_difference -> { Github::Event.count }, 1 do
      post github_events_url(id: @account.id),
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
      installation: {id: @installation.installation_id},
      after: "abc123def456",
      repository: {full_name: "holamendi/smol-roda"}
    }

    payload_json = payload.to_json
    signature = generate_github_webhook_signature(payload_json, @webhook_secret)

    assert_enqueued_with(job: Github::ProcessEventJob) do
      post github_events_url(id: @account.id),
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
      post github_events_url(id: @account.id),
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
      installation: {id: @installation.installation_id}
    }

    payload_json = payload.to_json
    signature = generate_github_webhook_signature(payload_json, @webhook_secret)

    assert_difference -> { Github::Event.count }, 1 do
      post github_events_url(id: @account.id),
        params: payload_json,
        headers: github_webhook_headers("installation", @github_app.app_id, signature).merge({
          "Content-Type" => "application/json"
        })
    end

    event = Github::Event.last
    assert_equal "installation.created", event.slug
  end

  private

  def post_signed_event(event, payload)
    payload_json = payload.to_json
    signature = generate_github_webhook_signature(payload_json, @webhook_secret)
    post github_events_url(id: @account.id), params: payload_json,
      headers: github_webhook_headers(event, @github_app.app_id, signature).merge("Content-Type" => "application/json")
  end
end
