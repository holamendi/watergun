# Verified dependency upgrades — October 11, 2026

## Scope and provenance

Replaces moving Rails `main` (8.2.0.alpha) with the latest **released stable Rails 8.1.4**, published September 24, 2026. Solid Queue 1.7.0 was published August 21, 2026. These are the actual `releases/latest` responses from `rails/rails` and `rails/solid_queue`, not assumptions based on version numbers. Ruby 4.0.7, Bundler 4.0.22 and Node **LTS** 24.21.0 are installed and exercised. Node 26 is not substituted for the requested LTS line. Bundled npm is 11.19.0.

The starting tree was `654216fab522ddd24021edfa4516b150db239c2d`; it is byte-identical to the UI squash merge `cefd08e72f5551ba22ad2f07d50dc6a6f09a3af8`. The dependency branch is based on merged `main`, so the PR does not carry duplicate UI commits. No application deployment, merge, auth feature, storage feature or concurrency tuning is included.

All 39 Linux-installed direct gems and all 12 direct npm packages match the primary registries' latest stable metadata at verification time. Of 40 Gemfile declarations, `tzinfo-data` is conditional for Windows/JRuby and is not installed or tested on this Linux runtime (registry latest 1.2026.5). Twenty-two direct gem versions and six direct npm versions changed. Groupdate's version did not change: Git commit `6255e750009fe6f651eb6dabe32e8f840cf3a73d` and tag `v6.8.0` compare identical (zero differing files). Both Rails and Groupdate now use released gems, not mutable Git branches. `bundle update --all` also refreshed compatible transitives; `bundle outdated --strict --parseable` exits 0 with no outdated compatible gems. This is Linux x86_64 verification, not a claim about untested platforms.

## Runtime and build pins

| Setting | Before | After |
| --- | --- | --- |
| Ruby / Docker / CI | 3.4.7 | 4.0.7 |
| Locked Bundler | 2.5.22 | 4.0.22 (explicit Docker and CI pin) |
| Node Docker / CI | 24.2.0 | LTS 24.21.0 (also `.tool-versions`) |
| Checkout action | v3 | v7.0.1, SHA-pinned |
| Setup Node action | v3 | v7.1.0, SHA-pinned |
| Setup Ruby action | floating v1 | reviewed v1 commit, SHA-pinned |
| npm installs | `npm install`, Docker discarded lockfile | `npm ci`, committed lockfile retained |
| Vite config | `vite.config.ts` | identical contents in `vite.config.mts` |

Vite 8 reported a real native-config warning for ESM syntax in the previous CommonJS-inferred filename. A failing filename acceptance check preceded the `.mts` rename; Vite Ruby 3.11.1 itself installs and watches this extension. Both final test and production builds pass without that warning. No package-wide ESM-mode change was needed. Existing Docker jemalloc/YJIT settings and all worker/process/thread defaults were left untouched; no memory improvement is claimed from dependency version changes.

## Direct gem versions

| Gem | Before | Verified after |
| --- | --- | --- |
| `alba` | 3.10.0 | 4.0.0 |
| `bcrypt` | 3.1.22 | 3.1.22 |
| `bootsnap` | 1.24.4 | 1.26.0 |
| `bytesize` | 0.1.2 | 0.1.2 |
| `chartkick` | 5.2.1 | 5.2.1 |
| `discard` | 1.4.0 | 2.0.0 |
| `dotenv` | 3.2.0 | 3.2.0 |
| `ed25519` | 1.4.0 | 1.4.0 |
| `faraday-retry` | 2.4.0 | 2.4.0 |
| `groupdate` | 6.8.0 (Git master) | 6.8.0 (released gem; identical source) |
| `honeybadger` | 6.6.1 | 6.9.3 |
| `http` | 6.0.3 | 6.0.4 |
| `jwt` | 3.2.0 | 3.3.0 |
| `lograge` | 0.14.0 | 0.15.1 |
| `mission_control-jobs` | 1.1.0 | 1.3.1 |
| `net-ssh` | 7.3.2 | 7.3.6 |
| `octokit` | 10.0.0 | 10.0.0 |
| `pagy` | 8.6.3 | 43.7.0 |
| `propshaft` | 1.3.2 | 1.3.2 |
| `puma` | 8.0.1 | 8.0.2 |
| `rack-mini-profiler` | 4.0.1 | 5.0.0 |
| `rails` | 8.2.0.alpha (Git main) | 8.1.4 |
| `solid_cable` | 3.0.12 | 4.1.0 |
| `solid_queue` | 1.2.4 | 1.7.0 |
| `pg` | 1.6.3-x86_64-linux | 1.7.0-x86_64-linux |
| `sshkey` | 3.0.0 | 3.0.0 |
| `store_attribute` | 2.1.1 | 2.2.0 |
| `store_model` | 4.6.0 | 4.6.1 |
| `turbo-rails` | 2.0.23 | 2.0.23 |
| `tzinfo-data` | not installed on Linux | not installed on Linux |
| `vite_rails` | 3.11.0 | 3.11.1 |
| `web-console` | 4.3.0 | 4.3.0 |
| `ruby-lsp-rails` | 0.4.8 | 0.4.8 |
| `minitest-spec-rails` | 7.4.1 | 7.4.1 |
| `mocha` | 3.1.0 | 3.1.0 |
| `selenium-webdriver` | 4.44.0 | 4.51.0 |
| `vcr` | 6.4.0 | 6.4.0 |
| `webmock` | 3.26.2 | 3.29.0 |
| `debug` | 1.11.1 | 1.11.1 |
| `standard` | 1.54.0 | 1.57.0 |

## Direct JavaScript versions

| Package | Before | Verified after |
| --- | --- | --- |
| `@hotwired/stimulus` | 3.2.2 | 3.2.2 |
| `@hotwired/turbo-rails` | 8.0.23 | 8.0.23 |
| `@stimulus-components/dropdown` | 3.0.0 | 3.0.0 |
| `@stimulus-components/notification` | 3.0.0 | 3.0.0 |
| `chart.js` | 4.5.1 | 4.5.1 |
| `chartkick` | 5.0.1 | 5.0.1 |
| `date-fns` | 4.1.0 | 4.4.0 |
| `vite-plugin-rails` | 0.1.0 | 0.6.0 |
| `@tailwindcss/vite` | 4.2.2 | 4.3.3 |
| `tailwindcss` | 4.2.2 | 4.3.3 |
| `vite` | 8.0.2 | 8.3.4 |
| `vite-plugin-ruby` | 5.2.0 | 5.2.5 |

## Compatibility work and real tests

Version/config acceptance gates were run and genuinely failed before each coherent dependency/config update. Runtime regressions, rather than invented incompatibilities, drove minimal compatibility fixes. Logs are retained outside Git. The Pagy migration was not deferred: the real API/controller/view integration exposed removed extras, Backend/Frontend modules, headers merge, previous-page, series and URL helpers. The resulting code preserves the existing custom markup, seven-slot pagination window, Page-Items/Current-Page/Total-Count/Total-Pages headers, previous/next Link semantics, empty pages and out-of-range rejection. The first API contract run also exposed the preexisting unqualified `AppResource` constant; qualification to `Api::V1::AppResource` preserves the existing serializer.

Solid Queue is still fork-supervised with threaded workers and the shared primary connection pool (`connects_to = nil`). The real Solid Queue adapter, PostgreSQL job serialization, claim, execution, finalization and rollback are tested, not just the test adapter. Existing StorageMount enqueue/rollback tests also pass. The optional 1.7 batches schema is deliberately not installed: upstream documents it as optional until 2.0, `Batch.migrated?` is false, and ordinary jobs demonstrably work. The official update generator was inspected with `--pretend`, without writing any migration. `solid_queue:check` says the configuration is valid. Memory/PSS/RSS and async-supervisor/fiber experiments are a separate synthetic benchmark; this PR makes no unmeasured claim and enables neither mode.

| Verification | Actual result |
| --- | --- |
| Original isolated full Rails suite | **288 runs, 1,877 assertions, 0 failures/errors/skips** |
| Final full Rails suite | **311 runs, 2,127 assertions, 0 failures/errors/skips** |
| Test and production Vite builds | Both pass; 343 transformed modules each |
| Production Rails eager boot | Pass, synthetic keys and guarded isolated DB only |
| Production Rails asset precompile | Pass |
| JavaScript clipboard regression | 1 pass, 0 failures |
| Static UI consistency | Pass |
| Real browser, widths 1280 / 390 / 320, including service edit | **257 checks**, screenshots retained |
| Changed Ruby files, StandardRB | Pass |
| Zeitwerk | Pass; preexisting non-eager `test/test_helpers` notice |
| Installer smoke, disposable Docker harness | Pass under sudo |
| npm clean install / audit | Pass; 0 reported vulnerabilities |
| Compatible gem outdated check | Exit 0; no outdated compatible gems |
| Six changed migration bodies, actual PostgreSQL execution | All six pass with only compatibility annotation changes |
| All 51 retained migrations from an empty DB | **Blocked by preexisting missing bootstrap history**, detailed below |
| Full application Docker image build | **Not verified**, insufficient host free disk |

The original suite used Ruby 3.4.7 and explicitly selected Node LTS 24.21.0 rather than the host's default Node 26.9.0. Final tests use Ruby 4.0.7 and the same Node LTS. New tests add version/build-policy, Pagy contract/boundary, and actual Solid Queue integration coverage.

## Migration review and concrete limitations

All six `ActiveRecord::Migration[8.2]` annotations and `ActiveRecord::Schema[8.2]` became `[8.1]`. **No migration DSL body or production schema column/index/constraint was changed.** `config.load_defaults 8.0` stays unchanged. A clean schema load succeeds on stable Rails. Each of the six modified migration bodies was actually executed against a disposable PostgreSQL predecessor-state fixture; theme/preceding columns end absent and all 12 byte metrics become bigint.

The requested full-chain empty-database check was actually attempted, not substituted with schema loading. It fails at the first retained migration, `20240708142437_add_first_signup_token_to_accounts`, because `accounts` does not exist. Commit `26fade9` deleted 99 bootstrap migrations in June 2024. An additional replay from its archived schema fails at old migration `20240807151042` because `cpu_usage` is already absent. A nearer December 2025 snapshot also fails to load on PostgreSQL because it contains historical SQLite `json_extract` indexes. These failures predate this upgrade. Production migration history was not rewritten to mask them.

Replaying the two create-table migrations on native PostgreSQL yields bigint reference IDs whereas the committed schema retains integer reference IDs inherited from historical conversion; column ordering also differs. These differences are recorded in the scratch schema diff; the production schema was not regenerated to introduce unrelated type changes. A true complete empty-DB historical replay and byte-identical migration-derived schema remain **unverified**. Fresh installations use the verified committed schema; existing installations retain their established migration history. Resolving the archived bootstrap/adapter history requires a separate explicitly scoped migration-history repair.

The host had only roughly 400–600 MB free during final verification, so a full multi-stage application Docker image build was not attempted. The real Ruby 4 bundle installation, deterministic npm install, production environment boot/assets, and installer Docker smoke are verified alternatives, not a fabricated image-build result. The PR still requires CI review and a full application image build on a host with adequate disk before any dependency deployment. No direct Linux dependency version is held below the verified stable registry version; these are verification/optional-feature limitations, not hidden major-version deferrals.

## Reproduce safely on a development server

Do not copy a production `.env`, production encryption keys or a production DATABASE_URL. Use a new isolated PostgreSQL database and synthetic secrets. Example after entering this checkout:

```bash
mise install ruby@4.0.7 node@24.21.0
mise exec ruby@4.0.7 node@24.21.0 -- bash
export RAILS_ENV=test POSTGRES_TEST_DB=watergun_dependency_upgrades_test
export POSTGRES_HOST=127.0.0.1 POSTGRES_PORT=5432
# Supply only your disposable local DB user's credentials:
# export POSTGRES_USER=... POSTGRES_PASSWORD=...
unset DATABASE_URL RAILS_MASTER_KEY BUNDLE_DEPLOYMENT BUNDLE_FROZEN
export SECRET_KEY_BASE=$(openssl rand -hex 32)
export ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=$(openssl rand -hex 32)
export ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=$(openssl rand -hex 32)
export ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=$(openssl rand -hex 32)
export GITHUB_APP_ID=123 GITHUB_APP_CLIENT_ID=fixture GITHUB_APP_CLIENT_SECRET=fixture
export BUNDLE_PATH="$HOME/.cache/watergun-dependency-upgrades-bundle"
gem install bundler -v 4.0.22 --no-document
bundle _4.0.22_ install
npm ci
bundle exec rails db:create db:schema:load
bundle exec vite build --clear --mode=test
bundle exec rails test
bundle exec rails zeitwerk:check
bundle exec rails solid_queue:check
bundle exec vite build --clear --mode=production
node --test test/javascript/clipboard_controller_test.mjs
script/check-ui-consistency
sudo bash scripts/test-install-smoke.sh
bundle outdated --strict --parseable
npm audit
```

Avoid logging all SQL in prolonged test runs. Verification used a scratch preload setting only its test process logger to ERROR; application logging configuration was not changed. Do not run remote SSH/jobs as part of this reproduction. Browser QA uses a second isolated DB `watergun_dependency_upgrades_browser`, fresh fixture state/session, loopback Rails port **3148**, and Vite port override **3147** (prebuilt assets; no dev server needed). Invoke `test/system/settings_browser_test.py` with its `--state`, `--output`, `--origin`, `--chromium`, and `--service-settings-path` arguments as documented in the design-system docs. Parent-delivered scratch runner/fixture scripts provide exact commands without sharing session/key material.

On a spacious build host, the remaining image check is `docker build --progress=plain -t watergun-dependency-upgrades:verify .`; building an image is not authorization to deploy or start production workers.

## Primary sources and retained evidence

- Rails stable release: https://github.com/rails/rails/releases/tag/v8.1.4
- Solid Queue release/upgrading: https://github.com/rails/solid_queue/releases/tag/v1.7.0 and https://github.com/rails/solid_queue/blob/v1.7.0/UPGRADING.md
- Groupdate source equality: https://github.com/ankane/groupdate/compare/v6.8.0...6255e750009fe6f651eb6dabe32e8f840cf3a73d
- Ruby releases: https://www.ruby-lang.org/en/downloads/releases/
- Node releases: https://nodejs.org/dist/index.json
- Bundler metadata: https://rubygems.org/api/v1/gems/bundler.json
- Every direct gem version: `https://rubygems.org/api/v1/gems/<name>.json`
- Every direct npm version: `https://registry.npmjs.org/<package>` (its `dist-tags.latest`)
- Reviewed actions: https://github.com/actions/checkout/releases/tag/v7.0.1 and https://github.com/actions/setup-node/releases/tag/v7.1.0
- Vite Ruby config-extension support: installed 3.11.1 `lib/vite_ruby/cli/install.rb` and `lib/vite_ruby/config.rb`; Pagy compatibility was based on its installed 43.7.0 source, not guessed old helpers.

Private/local scratch evidence is under `/home/ubuntu/.hermes/cache/scratch/watergun-dependency-upgrades`: `final-registry-verification.json`, `actual-version-diff.json` (including all 59 transitive changes), `suite-history.json`, actual RED/GREEN logs, `six-migrations-real.log`, `six-migrations-schema.diff`, the genuine failing full-chain logs, and browser screenshots/checks. Synthetic keys and browser session state are intentionally not committed or included in public delivery artifacts. The final scratch `DELIVERY.md` records the actual commit, PR, read-back CI result and reproduction commands.
