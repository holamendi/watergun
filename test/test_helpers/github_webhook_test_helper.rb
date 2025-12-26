module GithubWebhookTestHelper
  def generate_github_webhook_signature(payload, secret)
    payload_string = payload.is_a?(String) ? payload : payload.to_json
    "sha256=" + OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new("SHA256"),
      secret,
      payload_string
    )
  end

  def github_webhook_headers(event_type, app_id, signature = nil)
    {
      "Content-Type" => "application/json",
      "X-GitHub-Event" => event_type,
      "X-GitHub-Delivery" => SecureRandom.uuid,
      "X-GitHub-Hook-ID" => "123456789",
      "X-Hub-Signature-256" => signature
    }
  end
end
