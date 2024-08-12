class Github::EventsController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate!

  def create
    @github_integration = Github::Integration.find_by!(token: params[:token])
    create_and_process_event! if valid_request?
    head :ok
  end

  private

  def valid_request?
    signature = "sha256=" + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), @github_integration.webhook_secret, request.body.read)
    Rack::Utils.secure_compare(signature, request.headers["HTTP_X_HUB_SIGNATURE_256"])
  end

  def create_and_process_event!
    event = @github_integration.github_events.create!(
      account: @github_integration.account,
      headers: request.headers.to_h.slice(
        "HTTP_X_GITHUB_HOOK_ID",
        "HTTP_X_GITHUB_EVENT",
        "HTTP_X_GITHUB_DELIVERY",
        "HTTP_X_GITHUB_HOOK_INSTALLATION_TARGET_ID",
        "HTTP_X_GITHUB_HOOK_INSTALLATION_TARGET_TYPE"
      ),
      payload: JSON.parse(request.body.read)
    )

    Github::ProcessEventJob.perform_later(event)
  end
end
