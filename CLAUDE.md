# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Watergun is a Rails 8 application that manages Dokku-based deployments. It provides a web interface for managing servers, projects, apps, services, and deployments via SSH connections to Dokku hosts.

## Development Commands

```bash
# Start development server (uses overmind with Procfile.dev)
bin/dev

# Restart development server (kills and restarts bin/dev)
bin/dev-restart

# Run all tests
bin/rails test

# Run a single test file
bin/rails test test/models/server_test.rb

# Run a specific test by line number
bin/rails test test/models/server_test.rb:42

# Linting with StandardRB
bundle exec standardrb

# Auto-fix linting issues
bundle exec standardrb --fix

# Database migrations
bin/rails db:migrate

# Start background job worker separately
bundle exec rake solid_queue:start

# Vite asset compilation (handled by bin/dev, but can run standalone)
bin/vite dev
```

## Local Development

- **URL**: http://localhost:3000
- **Dev user**: hola@mendi.cl
- **Password**: abc123
- **Ruby version**: Managed by [mise](https://mise.jdx.dev/) (see `.mise.toml`)

## Architecture

### Core Domain Models

- **Account**: Multi-tenant root; owns servers, projects, users, and GitHub integrations
- **Server**: Physical/virtual host running Dokku; connects via SSH using stored ED25519 keys. SSH user is always `"watergun"`
- **Project**: Groups apps and services on a server; uses soft deletes
- **App**: Dokku application with deployments, domains, env variables, storage mounts. Has `dokku_id` (auto-suffixed to avoid collisions)
- **Service**: Dokku-managed services (postgres, redis, mysql, etc.) that can link to apps
- **Deployment**: Individual app deployment with status tracking. Source: web, api_v1, or github_webhook
- **Domain**: App domain with SSL tracking via Let's Encrypt
- **EnvVariable**: Encrypted env vars (`encrypts :value`). Filters reserved `DOKKU_` prefix
- **ServiceLink**: Join between App and Service, owns a DSN env variable
- **StorageMount**: Persistent volume mount with auto-derived host_path

### Current Context

`Current` extends `ActiveSupport::CurrentAttributes` with `session`, `user`, `membership`, `account`, `server`, `api_token`, `source`. Setting `user` auto-cascades to `membership`, `account`, and `server`.

### ServerAction Pattern

Server operations are modeled as `ServerAction` subclasses (STI) in `app/models/server_actions/`. Each action:
- Inherits from `ServerAction` base class
- Defines a `SLUG` constant for identification
- Uses `actionable` macro to specify the polymorphic target type
- Implements a private `run` method containing the operation logic
- Executes Dokku commands via SSH using `execute!` with command objects
- Can chain via `preceding_server_action_id` (cancelled if predecessor failed)

```ruby
class ServerActions::CreateApp < ServerAction
  SLUG = "apps.create"
  actionable App

  store_attribute :payload, :dokku_app_id, :string

  private

  def run
    execute!(Dokku::Apps::CreateCommand.new(app: dokku_app_id))
    app.active!
  rescue Ssh::CommandExecutionError
    app.error!
    raise
  end
end
```

Class-level helpers: `ServerActions::DeployApp.run_now!(server, deployment)` and `.run_later!(server, deployment, depends_on: preceding_action)`.

`RunServerActionJob` enforces 1 concurrent job per `concurrency_key` (usually the App or Service).

### Dokku Command Objects

Commands for Dokku operations live in `app/models/dokku/` organized by plugin:
- `apps/`, `git/`, `ps/`, `config/`, `domains/`, `letsencrypt/`, `builder/`, `services/`, `storage/`, `plugin/`, `docker/`, `system/`

Each command object implements `#cmd` returning the shell string. Some implement `#parse_output(exit_code, text_output)` for structured data.

### SSH Execution

`Server#ssh_session` establishes SSH connections (retries up to 4 times on timeout). `Ssh::Session` wraps `Net::SSH`. `#execute!` raises `Ssh::CommandExecutionError` on non-zero exit. All commands accumulated in `@commands` array for log persistence.

### Service Objects

Located in `app/models/<model>/` (e.g., `App::CreateApp`, `Deployment::CreateDeployment`). Follow `ActiveModel::Model` + `ActiveModel::Attributes` pattern with validations and `#save` method that wraps transactions.

### Background Jobs

Uses Solid Queue with SQLite. Jobs in `app/jobs/`:
- `RunServerActionJob`: Executes server actions via SSH, handles log persistence
- `FetchContainerMetricsJob`: Runs every 30s, collects docker stats from all servers
- `StartLogStreamJob`/`StopLogStreamJob`: Real-time log streaming via Turbo
- `Github::ProcessEventJob`: Processes webhook events, auto-deploys on push

Recurring jobs configured in `config/recurring.yml`.

### GitHub Integration

GitHub App registration (manifest flow) → Installation → Webhook events → Auto-deployments. Webhooks POST to `/github/events/:id`, verified via HMAC-SHA256. On `push` events, creates deployments for matching repos with `webhook_deploy: true`.

### API v1

Bearer token auth via `ApiToken`. Endpoints: apps (list/show), deployments (list/show), ping. Serialization uses `alba` gem with resources in `app/models/api/`.

### Frontend

- Vite with Stimulus.js controllers in `app/javascript/controllers/`
- Turbo for real-time updates and broadcasts (app/service status, deployments, logs, toasts)
- Tailwind CSS 4 with custom design system
  - **Design reference**: `docs/design-system/README.md`
  - Custom dark theme with colors: `base`, `surface`, `elevated`, `accent`, `success`, `warning`, `error`
  - Text colors: `text-primary`, `text-secondary`, `text-muted`
  - Use semantic color names for consistency
- Chartkick/Chart.js for metrics visualization

### Multi-Database Setup

Three SQLite databases (primary, queue, cable) per environment. Migrations for queue/cable have separate paths in `db/queue_migrate` and `db/cable_migrate`.

### Authentication

- **Web**: Cookie-based (`cookies.signed.permanent[:session_token]`, http_only, same_site: lax)
- **API v1**: HTTP Bearer token via `ApiToken`
- **Internal setup API**: `ACCOUNT_SETUP_TOKEN` env var
- **GitHub Webhooks**: HMAC-SHA256 signature verification
- **First run**: Signed user ID (purpose: `:first_run`)

## Code Style

Prefer vanilla Rails patterns over external dependencies.

- **Linting**: StandardRB (run `bundle exec standardrb --fix` to auto-fix)
- **Soft deletes**: Use `Discard::Model` with `.kept` scope for filtering
- **Multi-tenant defaults**: Use `belongs_to :account, default: -> { parent.account }`
- **Current context**: Use `Current.account`, `Current.user` for request context
- **Store attributes**: Use `store_attribute :payload, :field_name, :type` for JSON column fields
- **Enums**: Use custom `Enum[:pending, :active, :error]` syntax (generates string-keyed hash)
- **Broadcasts**: Use `after_update_commit` with `broadcast_replace_later_to`
- **Dokku ID collisions**: Apps and Services auto-append random hex suffix if parameterized name exists

## Testing

- Uses Minitest with `minitest-spec-rails` for spec-style syntax
- `parallelize(workers: :number_of_processors)`
- All fixtures loaded (`fixtures :all`)
- VCR/WebMock for HTTP request recording (cassettes in `test/vcr_cassettes/`)
- Mocha for mocking
- Test helpers in `test/test_helpers/`:
  - `SessionTestHelper`: `sign_in(user)` / `sign_out`
  - `SshTestHelper`: `mock_ssh_session(host:, user:, port:, private_key:, commands:)`
  - `ServerActionTestHelper`: `assert_server_action_scheduled(klass, server:, actionable:, payload:)`
  - `GithubWebhookTestHelper`: HMAC signature helpers
