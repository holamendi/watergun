class Github::EventsController < ApplicationController
  skip_forgery_protection

  skip_before_action :authenticate

  def create
    verify_signature!

    create_and_process_event!
  ensure
    head :ok
  end

  private

  def installation
    @installation ||= github_app.installations.where.not(installation_id: nil)
      .find_by!(installation_id: event_payload.dig("installation", "id"))
  end

  def github_app
    @github_app ||= if (account_id = params[:id].presence)
      Github::App.find_by!(account_id:)
    else
      Github::App.find_by!(account_id: nil)
    end
  end

  def event_payload
    @event_payload ||= JSON.parse(request.body.read)
  end

  def event_signature
    request.headers["HTTP_X_HUB_SIGNATURE_256"]
  end

  def verify_signature!
    signature = "sha256=" + OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new("SHA256"),
      github_app.webhook_secret,
      request.body.read
    )

    return if Rack::Utils.secure_compare(signature, request.headers["HTTP_X_HUB_SIGNATURE_256"])

    raise ActionController::BadRequest, "Invalid signature"
  end

  def create_and_process_event!
    event = installation.events.create!(
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
