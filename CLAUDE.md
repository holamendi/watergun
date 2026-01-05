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
- **Server**: Physical/virtual host running Dokku; connects via SSH using stored keys
- **Project**: Groups apps and services on a server
- **App**: Dokku application with deployments, domains, and environment variables
- **Service**: Dokku-managed services (databases, caches) that can link to apps
- **Deployment**: Individual app deployment with status tracking

### ServerAction Pattern

Server operations are modeled as `ServerAction` subclasses in `app/models/server_actions/`. Each action:
- Inherits from `ServerAction` base class
- Defines a `SLUG` constant for identification
- Uses `actionable` macro to specify the polymorphic target type
- Implements a private `run` method containing the operation logic
- Executes Dokku commands via SSH using `execute!` with command objects

Example: `ServerActions::DeployApp` deploys an app by syncing git and rebuilding.

### Dokku Command Objects

Commands for Dokku operations live in `app/models/dokku/` organized by plugin:
- `apps/`, `git/`, `ps/`, `domains/`, `letsencrypt/`, `config/`, `services/`, etc.

Each command object generates the appropriate `dokku` CLI command string.

### SSH Execution

`Server#ssh_session` establishes SSH connections. Commands are executed through `Ssh::Session` which wraps Net::SSH.

### Background Jobs

Uses Solid Queue with SQLite. Jobs are in `app/jobs/`:
- `RunServerActionJob`: Executes server actions asynchronously
- `FetchContainerMetricsJob`: Recurring job for container stats
- `StartLogStreamJob`/`StopLogStreamJob`: Real-time log streaming

Recurring jobs configured in `config/recurring.yml`.

### Frontend

- Vite with Stimulus.js controllers in `app/javascript/`
- Turbo for real-time updates and broadcasts
- DaisyUI 5 component library on Tailwind CSS 4 for styling
  - Docs: https://daisyui.com/llms.txt
  - Use semantic color names (`primary`, `success`, `error`) for theme consistency
  - Components use class naming: component (`btn`), parts (`card-body`), modifiers (colors/sizes)

### Multi-Database Setup

Three SQLite databases (primary, queue, cable) per environment. Migrations for queue/cable have separate paths in `db/queue_migrate` and `db/cable_migrate`.

## Code Style

Prefer vanilla Rails patterns over external dependencies.

- **Linting**: StandardRB (run `bundle exec standardrb --fix` to auto-fix)
- **Soft deletes**: Use `Discard::Model` with `.kept` scope for filtering
- **Multi-tenant defaults**: Use `belongs_to :account, default: -> { parent.account }`
- **Current context**: Use `Current.account`, `Current.user` for request context
- **Store attributes**: Use `store_attribute :payload, :field_name, :type` for JSON column fields
- **Enums**: Use custom `Enum[:pending, :active, :error]` syntax
- **Broadcasts**: Use `after_update_commit` with `broadcast_replace_later_to`

### Service Objects

Located in `app/models/<model>/` (e.g., `App::CreateApp`). Used for complex operations with validations:

```ruby
class App::CreateApp
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :project
  attribute :name

  validates :project, presence: true

  def save
    return false unless valid?
    Model.transaction do
      # create records, schedule server actions
    end
    true
  end
end
```

### Server Actions

Located in `app/models/server_actions/`. Each action executes commands on the target server via SSH (Dokku commands or any shell command):

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

Key patterns:
- Define `SLUG` constant for identification
- Use `actionable` macro for polymorphic target
- Implement private `run` method with operation logic
- Use `execute!` with Dokku command objects

## Testing

- Uses Minitest with `minitest-spec-rails` for spec-style syntax
- VCR/WebMock for HTTP request recording
- Mocha for mocking
- Test helpers in `test/test_helpers/`
- Fixtures in `test/fixtures/`
