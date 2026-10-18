module Api
  module V1
    class ApplicationController < ActionController::Base
      include Pagy::Method

      class_attribute :api_scope_rules, default: {}.freeze

      def self.api_scope(scope, only:)
        raise ArgumentError, "Unknown API scope" unless ApiToken::SCOPES.include?(scope)
        self.api_scope_rules = api_scope_rules.merge(Array(only).map { |action| [action.to_s, scope] }.to_h).freeze
      end

      before_action :set_source
      before_action :authenticate
      before_action :authorize_scope
      before_action :validate_path_ids

      rescue_from ActiveRecord::RecordNotFound, with: -> { api_error("not_found", :not_found) }
      rescue_from ServerAction::Accept::Error, with: :acceptance_error
      rescue_from ServerAction::Conflict::Error, with: -> { api_error("operation_conflict", :conflict) }

      skip_forgery_protection

      private

      def acceptance_error(error)
        status = {"invalid_request" => :bad_request, "unauthorized" => :unauthorized, "forbidden" => :forbidden,
                  "not_found" => :not_found, "idempotency_conflict" => :conflict, "prerequisite_missing" => :conflict,
                  "validation_failed" => :unprocessable_content, "unavailable" => :service_unavailable}.fetch(error.code)
        message = (error.code == "prerequisite_missing") ? "Provision an active Dokku server and accessible GitHub installation/repository; select a supported builder" : error.code.humanize
        api_error(error.code, status, message: message)
      end

      def validate_path_ids
        return if controller_name == "pings"
        ids = request.path_parameters.slice(:id, :app_id, :project_id).values
        raise ActiveRecord::RecordNotFound unless ids.all? { |id| id.is_a?(String) && id.match?(/\A[1-9][0-9]{0,18}\z/) }
      end

      def mutation_body
        raise ServerAction::Accept::Error, "invalid_request" unless request.query_parameters.empty?
        unless request.media_type == "application/json"
          api_error("unsupported_media_type", :unsupported_media_type)
          return
        end
        if request.raw_post.bytesize > 65_536
          api_error("request_too_large", :content_too_large)
          return
        end
        body = JSON.parse(request.raw_post)
        raise ServerAction::Accept::Error, "invalid_request" unless body.is_a?(Hash)
        body
      rescue JSON::ParserError
        raise ServerAction::Accept::Error, "invalid_request", cause: nil
      end

      def accept_operation(target, endpoint:, scope:, body: {}, prepare: nil, &block)
        run = ServerAction::Accept.call(token: Current.api_token, target: target, endpoint: endpoint,
          key: request.headers["Idempotency-Key"], request: body, request_id: request.request_id, scope: scope, prepare: prepare, &block)
        render_operation(run, status: :accepted)
      rescue ActiveRecord::RecordNotFound
        raise
      rescue ActiveRecord::ActiveRecordError => error
        ServerAction::Runner.report(error, nil, phase: "public acceptance")
        api_error("unavailable", :service_unavailable)
      end

      def source_prerequisites!(target)
        server = target.server
        installation = target.account.github_installation
        unless server.active? && server.cpu_type.present? && server.public_ip.present? && server.ssh_key &&
            installation&.installation_id.present? && installation.github_app.account_id == target.account_id
          raise ServerAction::Accept::Error, "prerequisite_missing"
        end
      end

      def usable_app!(app, deployed: false)
        unless app.server.active? && app.server.public_ip.present? && app.server.ssh_key
          raise ServerAction::Accept::Error, "prerequisite_missing"
        end
        if !app.status.in?(%w[active error]) || (deployed && !app.deployed?)
          raise ServerAction::Conflict::Error
        end
      end

      def account_projects
        Current.account.projects.kept.joins(:server).where(servers: {account_id: Current.account.id})
          .where("servers.status IS NULL OR servers.status != ?", "deleted")
      end

      def account_apps
        Current.account.apps.kept.where(project_id: account_projects.select(:id))
          .where.not(status: "deleted").where("apps.server_id = (SELECT projects.server_id FROM projects WHERE projects.id = apps.project_id)")
      end

      def page_records(records)
        query = request.query_parameters
        valid = (query.keys - %w[page limit]).empty? && query.values.all? { |value| value.is_a?(String) && value.match?(/\A[1-9][0-9]{0,8}\z/) }
        return api_error("invalid_request", :bad_request) unless valid
        page = query.fetch("page", "1").to_i
        limit = query.fetch("limit", "20").to_i
        unless limit.between?(1, 100)
          api_error("invalid_request", :bad_request)
          return
        end
        pagination, page_records = pagy(records.order(:id), page: page, limit: limit, client_limit: 100, raise_range_error: false)
        headers = pagination.headers_hash(headers_map: {page: "Current-Page", limit: "Page-Items", pages: "Total-Pages", count: "Total-Count"})
        response.headers.merge!(headers.except("link"))
        # Retain the public relative links, explicit first page and overflow's
        # previous requested page. Pagy owns counting, offsets and empty pages.
        url_options = {absolute: false, querify: ->(params) {
          params["page"] ||= 1
          params.replace(params.sort.to_h)
        }}
        urls = pagination.urls_hash(**url_options)
        urls[:previous] = pagination.page_url(page - 1, **url_options) if page > pagination.last
        response.headers["Link"] = {first: urls[:first], last: urls[:last], prev: urls[:previous], next: urls[:next]}.compact
          .map { |rel, url| "<#{url}>; rel=\"#{rel}\"" }.join(", ")
        page_records
      end

      # Shared by subsequent mutation controllers; acceptance itself never waits
      # for a worker or SSH. Polls preserve the original acceptance identity.
      def render_operation(run, status: :ok)
        raise ActiveRecord::RecordNotFound unless run.account_id == Current.account.id && run.request_id
        response.headers["Location"] = api_v1_operation_path(run)
        response.headers["Retry-After"] = "2"
        response.headers["Cache-Control"] = "no-store"
        render json: Api::V1::OperationResource.new(run), status: status
      end

      def authenticate
        authenticated = authenticate_with_http_token { |token, _| Current.api_token = ApiToken.authenticate(token) }
        unless authenticated
          response.headers["WWW-Authenticate"] = "Bearer"
          api_error("unauthorized", :unauthorized)
        end
      end

      def authorize_scope
        token = Current.api_token
        scope = api_scope_rules[action_name]
        permitted = token.permits?(scope) && (!token.read_only? || request.get? || request.head?)
        unless permitted
          return api_error("forbidden", :forbidden)
        end
        token.update_columns(last_used_at: Time.current)
      end

      def api_error(code, status, message: code.humanize)
        render json: {error: {code: code, message: message}, request_id: response.headers["X-Request-ID"]}, status: status
      end

      def set_source
        Current.source = :api_v1
        request.set_header("action_dispatch.request_id", SecureRandom.uuid)
        response.headers["X-Request-ID"] = request.request_id
      end
    end
  end
end
