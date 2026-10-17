class ServerAction::Accept
  SCOPES = {"apps.create" => "apps:write", "apps.destroy" => "apps:write", "apps.restart" => "apps:write",
            "apps.deploy" => "deployments:write", "apps.update_env" => "env:write"}.freeze
  class Error < StandardError
    attr_reader :code

    def initialize(code)
      @code = code
      super(code.humanize)
    end
  end

  def self.digest(value)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.key_generator.generate_key("public-operation-v1"), JSON.generate(canonical(value)))
  end

  def self.canonical(value)
    case value
    when Hash
      value.deep_stringify_keys.sort.to_h.transform_values { |child| canonical(child) }
    when Array
      value.map { |child| canonical(child) }
    else
      value
    end
  end

  def self.call(token:, endpoint:, target:, key:, request:, request_id:, scope:, prepare: nil)
    connection = ServerActionRun.connection
    if connection.transaction_open?
      raise ArgumentError, "Acceptance must own its commit"
    end
    raise Error, "invalid_request" unless key.is_a?(String) && key.match?(/\A[A-Za-z0-9._:-]{1,128}\z/)
    raise Error, "invalid_request" unless request_id.is_a?(String) && request_id.match?(/\A[A-Za-z0-9._:-]{1,128}\z/) && request.is_a?(Hash)
    identity = digest([endpoint, target.class.base_class.name, target.id, key])
    fingerprint = digest(request)
    # Slow source resolution happens without row locks, and committed retries
    # never consult GitHub again. The transaction below rechecks the winner and
    # authorization; callers compare their prepared source with the locked target.
    prepared = prepare.call if prepare && !ServerActionRun.exists?(account_id: token.account_id, api_token_id: token.id, idempotency_digest: identity)
    replay = false
    accepted_id = nil
    accepted_runs = []
    begin
      run = ServerActionRun.transaction do
        token.lock!
        authorize!(token, scope)
        Current.set(user: token.user, api_token: token, account: token.account, source: :api_v1, accepting_server_action: accepted_runs) do
          existing = ServerActionRun.find_by(account_id: token.account_id, api_token_id: token.id, idempotency_digest: identity)
          if existing
            raise Error, "idempotency_conflict" unless existing.request_fingerprint == fingerprint
          end
          target = target.class.find_by(id: target.id)
          if target
            target.lock! unless target.is_a?(Project)
            project = target.is_a?(Project) ? target : target.project
            project.lock!
            raise Error, "not_found" unless target.is_a?(Project) || target.project_id == project.id
            raise Error, "not_found" unless target.account_id == token.account_id
            target.server.lock!
            begin
              ServerAction::TargetValidation.app_context!(target, account: token.account, user: token.user)
            rescue ArgumentError
              raise Error, "not_found"
            end
          elsif !existing
            raise Error, "not_found"
          end
          if existing
            replay = true
            next existing
          end
          accepted = yield(target, prepared)
          unless accepted.is_a?(ServerActionRun) && accepted.persisted? && accepted_runs.size == 1 && accepted_runs.first.id == accepted.id
            raise ArgumentError, "Expected exactly one newly enqueued server action run"
          end
          raise Error, "forbidden" unless SCOPES[accepted.action_key] == scope && accepted.account_id == token.account_id
          app = accepted.target.is_a?(App) ? accepted.target : accepted.target.app
          bound = target.is_a?(Project) ? (app.project_id == target.id && accepted.action_key == "apps.create") : (app.id == target.id)
          raise ArgumentError, "Accepted action target mismatch" unless bound
          accepted.update!(api_token_id: token.id, user_id: token.user_id, request_id: request_id,
            idempotency_digest: identity, request_fingerprint: fingerprint,
            operation_app_id: app.id, operation_deployment_id: accepted.target.is_a?(Deployment) ? accepted.target_id : nil)
          accepted_id = accepted.id
          accepted
        end
      end
    rescue => error
      # An after_commit notification can fail after the acceptance transaction
      # has committed. Only a fresh read of our exact atomic acceptance proves it.
      run = ServerActionRun.find_by(id: accepted_id, api_token_id: token.id, idempotency_digest: identity) if accepted_id
      raise unless run
      ServerAction::Runner.report(error, run.id, phase: "acceptance notification")
    end
    begin
      ServerAction::Enqueue.schedule(run) unless replay
    rescue => error
      ServerAction::Runner.report(error, run.id, phase: "accepted dispatch")
    end
    run
  end

  def self.authorize!(token, scope)
    membership = Membership.lock.find_by(user_id: token.user_id, account_id: token.account_id)
    raise Error, "unauthorized" if token.revoked_at || token.expires_at <= Time.current || !membership
    raise Error, "forbidden" unless SCOPES.value?(scope) && token.permits?(scope) && !token.read_only?
  end
end
