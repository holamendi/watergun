class Github::EventsController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate

  def create
    validate_signature!

    create_and_process_event! if valid_request?
  ensure
    head :ok
  end

  private

  def installation
    @installation ||= Github::Installation.find_by!(installation_id: event_payload.dig("installation", "id"))
  end

  def github_app
    @github_app ||= installation.github_app
  end

  def event_payload
    @event_payload ||= JSON.parse(request.body.read)
  end

  def github_app_id
    request.headers["HTTP_X_GITHUB_HOOK_INSTALLATION_TARGET_ID"]
  end

  def event_signature
    request.headers["HTTP_X_HUB_SIGNATURE_256"]
  end

  def valid_request?(webhook_secret)
    signature = "sha256=" + OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new("SHA256"),
      @github_app.webhook_secret,
      request.body.read
    )

    Rack::Utils.secure_compare(signature, request.headers["HTTP_X_HUB_SIGNATURE_256"])
  end

  def create_and_process_event!
    event = @installation.events.create!(
      account: @github_integration.account,
      headers: request.headers.to_h.slice(
        "HTTP_X_GITHUB_HOOK_ID",
        "HTTP_X_GITHUB_EVENT",
        "HTTP_X_GITHUB_DELIVERY",
        "HTTP_X_GITHUB_HOOK_INSTALLATION_TARGET_ID",
        "HTTP_X_GITHUB_HOOK_INSTALLATION_TARGET_TYPE"
      ),
      payload: event_payload
    )

    Github::ProcessEventJob.perform_later(event)
  end
end
