# Agentic readiness

What went wrong with the October Codex run, and what to change before handing Watergun to agents again.

Written 2026-11-01 from the PR history (`gh pr view/diff`), the `main` activity log, the rolled-back commits on `origin/refactor/api-style-and-behavior`, and the current code on `main` (`868c086`).

## Summary

- **The bug fixes were mostly good. The process around them failed.** The Oct 13 batch fixed real bugs in about 190 lines of app code. Those lines came with about 2,200 lines of tests, and nobody read either.
- **Merging to `main` deploys production, and nothing treated it that way.** Every Codex PR said "no production changes". Each merge auto-deployed and ran its migrations. Three migrations went out this way, one of them irreversible.
- **The rollback was a force-push, and the database stayed migrated.** `main` went back to `e50221f`, the database stayed on the newer schema, and the app broke for two weeks. Error reporting was off, so nobody noticed. The `/up` health check kept passing the whole time.
- **No human ever reviewed the work.** Across 26 PRs there's one human review comment, on #61. Six PRs were merged under three minutes after being opened, one of them a 1,165-line PR. GitHub shows every PR, merge and the force-push as `holamendi`, so the history can't tell Pablo's actions from Codex's.
- **The scope kept growing past what was asked.** "Get the codebase in a good place" turned into a new action framework (#68), a public API with idempotency keys and operation records (#79–#85), and then a 12,000-line fix for that work (#86).
- **Fix order:** first two real security bugs, error reporting, branch protection, and a health check that catches a code/schema mismatch. Then agent rules, the PR policy and the migration policy. Then re-land the good hardening fixes one at a time.

## 1. Timeline

| When (UTC) | What |
|---|---|
| Oct 11 16:32 → Oct 12 03:03 | Codex opens #52–#66, one every ~45 min, each branched from the same `main` |
| Oct 12 04:06 | Pablo's only review comment: "can we avoid a nested rescue?" on #61 |
| Oct 13 02:17–02:31 | #52–#66 merged in 14 minutes. Combined, they break fixtures, so #67 is opened and merged in 1 m 45 s, partway through the batch |
| Oct 13 17:46 | #68 merged (+2,064/−1,316, 103 files): STI replaced by `server_action_runs`, all payloads encrypted, per-server locking |
| Oct 15 18:04 | #69 restores the per-app/service concurrency that #68 had changed |
| Oct 17 09:36 | Codex opens epic issue #70 and sub-issues #71–#78 for a public API |
| Oct 17 12:11–17:24 | #79–#85 merged, one per sub-issue, five of them 2–3 minutes after opening. Prod auto-deploys `3513fd5` and runs the #80 (irreversible) and #83 migrations |
| Oct 18 10:08 | Draft #86 opened (+12,167/−1,189, 223 files, "766 tests") to repair #79–#85 |
| Oct 18 10:16 | `main` force-pushed `3513fd5` → `e50221f`. #86 closed. Issues #70, #77, #78 later deleted |
| Oct 18 → Nov 1 | Prod runs `e50221f` against the migrated schema: every server action fails with `PG::UndefinedTable`. Watergun can't deploy itself, because deploys are server actions too |
| Oct 20 | #87 merged: four of the batch's fixes redone, plus dead-code removal |
| Nov 1 | `868c086` restores the schema, deployed by hand through Dokku. Same day: CI lint, a pre-commit hook, doc fixes |

## 2. The clusters

### #52–#67: the Oct 13 hardening batch

**What it attempted:** 15 independent fixes for real bugs, one per PR, plus #67 to reconcile fixtures after merging.

**Assessment:** Mostly sound. The app-code changes are small (2–31 lines each) and most target real bugs that still exist on `main`:

| PR | Fix | Verdict |
|---|---|---|
| #52 | Projects can't point at another account's server | Sound idea. The `DestroyProject` re-validation (reload, `errors.clear`, three nested checks inside `run`) is over-built |
| #53 | First-run tokens expire and work only once (`generates_token_for`) | Good, vanilla Rails. The `with_lock` plus re-find is more than needed |
| #54 | Expired API tokens rejected. Mission Control locked to `JOBS_ADMIN_USER_IDS` | The expiry fix was redone in #87. The jobs lock is right in principle, but it was a product decision made without asking: it locks everyone out unless an env var is set |
| #55 | Encrypt `UpdateEnv` payloads. Redact `config:set`/`config:export` in logs | **Real secret leak, still open on `main`** (see §4.1) |
| #56 | App stays visible as `deleting` until Dokku confirms | Sound |
| #57 | SSH retries are bounded | Correct. Lost in the rollback, redone in #87 |
| #58 | Renaming an env var unsets the old name in Dokku | Real bug, 4 lines, still open |
| #59 | Webhooks routed by installation id. Push refs parsed properly | The ref fix was redone in #87. The installation fix (`installations.first`) is still open |
| #60 | Removes the "connect repo to an existing app" flow | **Removed a feature without asking.** Don't re-land unless Pablo wants it |
| #61 | Failures caught by an `on_failure` hook, not each action's `rescue` | Kept on `main` (the rollback target was #61's branch tip) |
| #62–#66 | Move each action's `rescue Ssh::CommandExecutionError` into `on_failure` | Sound and consistent with #61. The `@x_completed && record.reload.active?` guards are written for failures nobody has seen |
| #67 | Fixture repair after the batch merged | Symptom: the PRs passed CI separately but broke when combined |

**What was sloppy:**
- About 2,180 lines of tests for about 190 lines of code. Many tests stub Rails internals to raise just to test failure paths nobody has hit, like "activation broadcast failure preserves the persisted active domain" or "creation reconciliation rejection preserves an unexpected SSH exception". They pin the implementation, not the behavior.
- 15 PRs all branched from one `main` and were never re-tested against each other. CI was green on each and red on the combination, which is what #67 patched.

**Worth re-landing:** #55, #58, #59 (installation routing), #52 (validations only), #53, #56, #62–#66 as one consolidation PR. All without the speculative guards and with a few tests each. See §5.

### #68–#69: STI → `server_action_runs`

**What it attempted:** Replace `ServerAction` STI with plain action classes plus a persisted `ServerActionRun`, a registry, and `Enqueue`/`Runner`/`LogPersistence`/`TargetValidation` helpers. Callers would use string keys (`"apps.restart"`) instead of classes. It also encrypted every payload and moved locking to one lock per server.

**Assessment:** Not sound for this codebase. STI with `run_now!`/`run_later!` is simple, documented in `AGENTS.md`, and was working. The rewrite added 5 helper modules and string-keyed dispatch. Locking per server serialized every action on a host, so #69 had to restore per-app concurrency two days later. Encrypting payloads was the useful core (the `UpdateEnv` secret leak), and #55 had already done that in one line.

The migration itself was careful: it refused to run with active jobs, and it had a working `down`. But it renamed a table and its columns in place, while Dokku's zero-downtime deploy keeps old containers running against the new schema. Codex wrote "drain old workers before rollout" in the PR body. The pipeline can't drain workers, and nobody read the PR body.

**Worth re-landing:** nothing as a unit. Encrypting `UpdateEnv` payloads comes back through #55. Keep STI. Write that down as a decision (§4.2).

### #70–#78: issues, not PRs

#70 was an epic, "Public API". #71–#76 were its sub-issues (contract, tokens, shared commands, durable operations, lifecycle endpoints, env writes), each closed by one of #79–#85. #77 (operation and log resources, per #80's body) and #78 ("real isolated Dokku release verification", per #84's body) were paused. #70, #77 and #78 now return HTTP 410 "This issue was deleted". Codex planned the work as issues and then ran through all of it in one afternoon. Each sub-issue says "No production changes are authorized", which was impossible: merging to `main` deploys.

### #79–#85: public API v1

**What it attempted:** An OpenAPI contract (701 lines of docs plus a schema checker and the `json_schemer` gem). API tokens stored as SHA-256 digests with scopes, audits, rotation and revocation. Shared lifecycle service objects. "Durable operation acceptance": idempotency keys, request fingerprints, conflict detection and recovery, 10 new columns on the action table. Then project/app/deployment endpoints with Alba, and write-only env batches.

**Assessment:** Partly sound, far too big for the need. Storing token digests and adding expiry and scopes is good practice. Moving env-var and builder logic into `app/models/<model>/` service objects matches the documented pattern. But idempotency keys, operation envelopes, fingerprints and outcome-uncertainty flags are platform-scale machinery for a single-operator Dokku panel with no API clients asking for them. About 1,200 lines of code, 3,760 lines of tests and 810 lines of docs went in over five hours.

The #80 migration (`DigestApiTokens`) drops the plaintext token column and raises `IrreversibleMigration` in `down`. It was merged 23 minutes after opening.

**Worth re-landing, later and only if an API consumer exists:**
- Token digests (`ApiToken` with `token_digest`, looked up by digest), as its own PR. Plan the migration explicitly, because it invalidates nothing yet can't be undone.
- `EnvVariable::CreateEnvVariable`/`UpdateEnvVariable`/`DestroyEnvVariable` service objects, if the env controller grows.
- Skip the operation and idempotency layer and the OpenAPI checker until a real client needs them.

### #86: the closed draft

**What it attempted:** Repair #79–#85 ("restore service boundaries and repair lifecycle behavior") and stop the drift with gates: the `archspec` gem plus `Archspec.rb`, `script/check-style-boundaries` (a Prism-based checker), a test that runs them against "sabotage fixtures", and `docs/coding-and-testing.md`.

**Assessment:** Codex noticed the architecture drifting and tried to fix it with more machinery: a new gem, a custom static checker, tests for the checker, and 7,500 more lines of tests. Its coding guide is hard to act on: "Every guard needs one owner and an input/time boundary… No Result/bus/validator/context/AndSync layer". Closing it was right.

**Worth keeping:** one idea. Point agents at existing exemplar files ("copy `App::CreateApp`, test like `create_app_test.rb`"). That works, written in plain words in `AGENTS.md`.

### #87: the follow-up, and how it differs

#87 redid four batch fixes (SSH retry cap, push refs, expired tokens, webhook deployment link), removed dead code, and fixed the lint offenses. It was 30 lines of code added and 151 removed, with 184 lines of tests.

| | Codex PRs | #87 |
|---|---|---|
| Body | Test counts, "independent review passed", jargon ("reconcile", "durable acceptance", "ownership") | Each fix: what was broken, the user-visible effect, what changed |
| Scope | Grew per PR | Explicit "Not included" section for a fix that would widen scope |
| Tests | ~11:1 test:code, fault-injection-heavy | ~6:1, each test failed before its fix |
| Net code | Mostly added | Removed more than it added |
| Open → merge | 2 min to 34 h, no reading | ~9 h |

#87 still bundled 7 fixes in one PR. They were separate commits, but one PR per fix would have been easier to review and to revert. Treat the commit style as the model, not the bundling.

## 3. Why it went wrong

1. **Merge meant deploy, and no one designed for that.** Watergun deploys itself on every push to `main`, and the release phase runs `db:prepare`. Every merge was a production migration. Codex kept writing "no production deployment performed" because it never ran a deploy command, but its merges did.
2. **There was no review step.** Branch protection is off, the repo is public, and the agent worked as `holamendi`. Nothing stopped a merge, and GitHub can't require approval when author and approver are the same account.
3. **Batches and speed.** 15 PRs merged in 14 minutes, each tested only against the old `main`. The API cluster went from issue to production in one afternoon. Review time per PR was effectively zero.
4. **Size.** #68 was 103 files and #86 was 223. Nobody reads that, so a size limit is the only way review stays possible.
5. **Unsafe migrations.** #68 renamed a table and its columns in place while old processes were still running. #80 was irreversible. The rollback reset code but never ran `down` for the migrations it removed. Once the migration files are gone from the code, `db:rollback` can't run them anymore.
6. **More tests, little signal.** The suite grew from 337 to 718 tests in six days (766 in #86). The tests asserted the agent's own implementation, like `on_failure` branches and `reload.active?` guards, against stubbed faults. None covered the failure that actually happened, code running against the wrong schema, because no test can see that. Green CI read as safe, and it wasn't.
7. **Docs and architecture drifted.** #68 changed the central pattern `AGENTS.md` describes, and #69 rewrote `AGENTS.md` to match. Then #80–#86 each added another layer (Accept, Conflict, Recovery, ResourceKey). The documented architecture followed the agent instead of steering it.
8. **Agents verified their own work.** Every PR said "independent review passed". That was Codex reviewing Codex, which isn't independent review.
9. **Nothing was watching production.** Honeybadger is in the Gemfile, but prod has no API key. `/up` only checks that Rails boots. Two weeks of 100% action failures raised no alert.

## 4. Recommendations

Ordered by priority. P0 is this week and small. Each item is its own PR.

### 4.1 P0: real issues on `main` now

1. **XSS in `LogsHelper#ansi_to_html`** (`app/helpers/logs_helper.rb`). It runs ANSI regexes over raw text and returns `data.html_safe`. It renders build output and also runtime logs (`dokku logs`, `shared/log_streams/_log`). Runtime logs carry internet-controlled text like request paths and user agents. Anyone who can make a deployed app log `<img src=x onerror=…>` gets script running in the Watergun admin session. Fix: `ERB::Util.html_escape` the input first, then turn the ANSI codes into spans. Also stop using `gsub!`, which mutates the caller's string. Add a helper test with `<script>` in the input.
2. **Env secrets stored in clear in the database and shown in the UI.**
   - `ServerActions::UpdateEnv` stores `set:` values as plain JSON in `server_actions.payload`.
   - `Dokku::Config::SetCommand` has no `redacted_cmd`, so the command saved to `server_action_logs` includes every value (base64, so effectively plaintext).
   - `PullEnv` runs `config:export`, and its full output (every env var) is saved to `server_action_logs`.

   Re-land #55: `encrypts :payload` on `UpdateEnv`, `redacted_cmd` on `SetCommand`, and a "sensitive output" flag on `ExportCommand`. Also delete the existing log rows that contain secrets.
3. **Turn on error reporting.** Set `HONEYBADGER_API_KEY` on the Dokku app and confirm with `bundle exec honeybadger test`. Add Honeybadger check-ins for the recurring jobs. No new dependency.
4. **Protect `main`.** Add a ruleset on `main`: block force pushes and deletion, require a PR, require the `test` check, require branches to be up to date. Up-to-date would have caught #67's breakage before merge. Give Pablo a bypass for emergencies only.
5. **Make `/up` fail on a code/schema mismatch.** The app manifest's healthcheck already hits `/up`. If `/up` returns 503 when the database has migrations the code doesn't know about (or the reverse), Dokku keeps the old container and the Oct 18 deploy fails loudly instead of breaking quietly. Sketch, not tested:

   ```ruby
   class HealthController < ActionController::Base
     def show
       pool = ActiveRecord::Base.connection_pool
       known = pool.migration_context.migrations.map { it.version.to_s }
       applied = pool.schema_migration.versions
       head((applied.sort == known.sort) ? :ok : :service_unavailable)
     end
   end
   ```

6. **Lock down Mission Control.** Today any signed-in user from any account can see and retry every job, including job arguments. Restrict it (an admin flag, or the env allowlist from #54 with a clear error when it isn't set).

### 4.2 P1: agent instructions

`AGENTS.md` is a good architecture reference. Its first line still reads "guidance to Codex (Codex.ai/code)", a leftover find-and-replace. It says nothing about limits.

- **Add `CLAUDE.md`** containing just `@AGENTS.md`, so Claude Code and the `claude-code-review` workflow read the same file. That workflow already tells the reviewer to "use the repository's CLAUDE.md", which doesn't exist yet. Keep one source of truth.
- **Add a "Rules for agents" section to `AGENTS.md`**, short and blunt:
  - **Never:** push to `main`, force-push any shared branch, merge a PR, deploy, run commands against `watergun-host` or `watergun.mendi.cl`, delete issues, close other people's PRs.
  - **Ask first (stop and write the question in the PR or chat):** any migration, any new gem or npm package, removing a user-facing feature or route, changing auth/tokens/encryption, changing the `ServerAction` base class or job concurrency, public API changes, anything over the size limit.
  - **Always:** one concern per PR; a regression test that fails before the fix; the PR body says what was broken, why, and how it was tested, in plain words; no claims of "independent review".
  - **Style:** vanilla Rails first, no new abstractions (registries, runners, result objects, DSLs) without an approved ADR, no comments that restate the code, and reasoning goes in the commit message.
  - **Exemplars:** the files to copy. For a server action, `app/models/server_actions/create_app.rb` and its test. For a service object, `app/models/app/create_app.rb`. For SSH tests, `test/test_helpers/ssh_test_helper.rb`.
- **Add short ADRs** in `docs/adr/`, one page each, recording decisions agents would otherwise reopen:
  1. `ServerAction` stays STI with `run_now!`/`run_later!`; the #68 rewrite was rejected.
  2. Service objects live in `app/models/<model>/`, use `ActiveModel::Model`, and `#save` returns a boolean.
  3. No new dependencies without Pablo's approval; prefer what Rails ships.
  4. Migrations are forward-only and expand/contract (see 4.4).
  5. API scope: v1 stays read-mostly until a real consumer exists. No idempotency or operations layer.
- **Agent permissions:** add deny rules to a committed `.claude/settings.json` for `git push --force*`, `git push origin main*`, `gh pr merge*`, `gh issue delete*`, and `ssh watergun*`. Set Codex's approval policy the same way. These are guardrails; the ruleset in 4.1.4 is what actually enforces them.

### 4.3 P1: PR policy for agents

- **One concern per PR.** A bug fix fixes one bug. Refactors and features are separate PRs.
- **Size:** aim for under 200 changed lines of app code and under 400 total, not counting `db/schema.rb` and lockfiles. Anything bigger needs an issue with a plan Pablo has approved, then lands in slices.
- **No stacks, no batches.** Merge one PR, let it deploy, check the app, then merge the next. Never queue several agent PRs at once.
- **Pablo merges, agents never do.** For "required review" to mean anything on GitHub, the agent needs its own identity: a separate bot account or a GitHub App token for Codex/Claude. Then require 1 approval and add `CODEOWNERS` for `db/`, `Gemfile*`, `config/`, `.github/`, `app/models/server_action.rb` and `AGENTS.md`. Until then, the rule is procedural, backed by the deny rules.
- **Never rewrite `main`.** To undo merged work, `git revert` it in a new PR. See 4.4 for the migration part.
- **Consider separating merge from deploy** while agents are active. Point Watergun's own `github_repo` at a `production` branch that only Pablo fast-forwards. That's a settings change, no code. Merging to `main` then stops deploying immediately, and deploys become a deliberate step.

### 4.4 P1: migrations and deploys

**Rules:**
- **Forward-only.** Undo a schema change with a new migration, as `868c086` did. Never by resetting code.
- **Expand/contract for renames and type changes.** Add the new table or column, write to both, backfill, switch reads, then drop the old one in a later release. Dokku runs old and new containers side by side during a deploy, so a one-step rename always breaks one of them.
- **Irreversible migrations** (dropping data, hashing secrets) need Pablo's explicit approval in the PR and a backup taken right before deploy (`dokku postgres:export`).
- **Migrations land alone.** A PR with a migration contains only the migration and the minimum code that uses it.

**Rolling back code that ran migrations:**
1. Don't force-push. Find the migrations in the range: `git diff --name-only GOOD..BAD -- db/migrate`.
2. If they're reversible, run `bin/rails db:migrate:down VERSION=…` on prod while the newer code is still deployed. Once the files are gone, Rails can't run their `down`. Then deploy the revert PR.
3. If they're irreversible, write a forward migration that restores the old schema, guarded so it's a no-op when there's nothing to undo. Deploy it with the revert.
4. Confirm `/up` (now schema-aware) is green and a test action (restart a throwaway app) succeeds.

**Release checklist** (paste into PRs that touch `db/` or deploy config):

- [ ] Migration is additive, or follows expand/contract
- [ ] `down` works (`bin/rails db:migrate:redo`), or irreversibility is approved and a backup is taken
- [ ] Old code still works against the new schema
- [ ] Deployed alone, with Pablo watching
- [ ] After deploy: `/up` green, one server action succeeds, Honeybadger quiet
- [ ] Rollback plan written in the PR body

### 4.5 P1: CI gates

| Gate | Status | Note |
|---|---|---|
| StandardRB | exists (CI + pre-commit) | |
| `rails test` | exists | |
| Installer smoke, UI consistency, Vite build | exist | |
| `db:schema:load` | exists | Only proves `schema.rb` loads, not that migrations produce it |
| `@claude` review on comment | exists | Opt-in; points at the missing `CLAUDE.md` |
| `bin/rails zeitwerk:check` | **add** | One line. Catches misnamed files (#69 added it before the rollback) |
| Migration check | **add** | Load the base branch's schema, run `db:migrate`, `git diff --exit-code db/schema.rb`, then `db:migrate:redo` for new migrations |
| Brakeman, bundler-audit | **add** | Both are in the default Rails 8.1 Gemfile, so this counts as vanilla Rails. Don't expect Brakeman to catch the helper XSS; the helper test does |
| PR size / label check | **add** | A few lines of shell over `git diff --numstat`: fail above the limit unless Pablo adds a `large-change` label. Same for `db/migrate` and `Gemfile.lock` (`needs-owner`) |
| Up-to-date branches | **add** (ruleset) | Prevents the #67 pattern |

**Observability**, beyond Honeybadger and `/up`: a recurring job that reports to Honeybadger when the last N server actions all failed or a deployment has been pending for over 15 minutes. That would have caught Oct 18 within minutes. Stuck deployments should also show in the UI.

### 4.6 P2: test strategy

**RSpec vs Minitest: stay on Minitest.**

- **Cost of switching:** about 358 tests in about 70 files, plus the helpers in `test/test_helpers/`, fixtures wiring, Mocha usage and CI. An agent could convert it in a day. But the result is a multi-thousand-line diff meant to change no behavior, and checking it means verifying that no assertion was lost or weakened. That's the review-proof mega-PR this report argues against.
- **Benefit:** `let`, shared examples and nested contexts. `minitest-spec-rails` already provides `describe`/`it`. Agents write both fluently. RSpec adds `rspec-rails` and usually `factory_bot`/`shoulda`, against the vanilla-Rails preference. You'd give up `bin/rails test file:line`, the built-in parallelization and the Rails generators.
- **What actually went wrong** was what the tests checked, and RSpec doesn't change that.
- **Optional cleanup:** the suite mixes `test "…"` (53 files) and `describe` (14 files). Settle on `test "…"` for new tests. Converting the 14 files and dropping `minitest-spec-rails` is a small PR, if it bothers you.

**Keeping tests high-signal (put this in `AGENTS.md`):**
1. A bug-fix test must fail before the fix. Say so in the PR.
2. Assert at the boundary: the exact Dokku command sent (`mock_ssh_session`), the persisted record state, the HTTP response, the broadcast. Not private methods or instance variables.
3. No fault-injection tests for failures nobody has seen. Stubbing `broadcast_replace_later_to` to raise tests the stub, not the app.
4. Extend existing test files and helpers. No new test DSLs, scenario builders or gems.
5. Review smell: more than about 5 lines of test per line of fix means the tests are probably restating the implementation.
6. **Characterization tests before refactors:** first a PR that adds tests pinning current behavior, with no app changes, merged on its own. The refactor PR must then pass them unmodified.
7. Add a handful of integration tests for the flows that matter (create app → deploy → view logs; set env var → Dokku `config:set`; GitHub push → deployment). Today there is one integration test file, with 3 tests. These catch more than another hundred unit tests.

## 5. Re-land backlog

Small PRs, in this order, one at a time, each through the new policy. Source PRs are listed so the diffs can be mined, not cherry-picked.

1. Escape `ansi_to_html` input (new; §4.1.1)
2. Encrypt `UpdateEnv` payloads and redact config commands and output (#55)
3. Schema-aware `/up` (new; §4.1.5)
4. `CLAUDE.md`, the `AGENTS.md` rules section and the first ADRs (new)
5. Env var rename unsets the old name (#58, ~4 lines)
6. Webhook installation routing by `installation.id` (#59, the part #87 didn't cover)
7. Mission Control access restriction (#54, with a non-silent default)
8. Project/server account validations (#52, model validations only)
9. First-run token expiry via `generates_token_for` (#53, without the lock dance)
10. `deleting` app status (#56)
11. `on_failure` consolidation across server actions (#62–#66, one PR, without the speculative `reload` guards)
12. `source: github_webhook` on webhook deployments (left out of #87)
13. Later, only with a consumer: API token digests (#80, its own migration PR with the checklist)

Not re-landing: #60 (removed a feature), #68/#69 (rejected architecture), #83 (operations/idempotency layer), #79's OpenAPI checker, #86's ArchSpec/Prism gates.

## Appendix: PR sizes and review time

Lines added to app code / tests / docs, from `gh pr diff`. Merge time is from open to merge.

| PR | Code + | Test + | Docs + | Migration | Open → merge | Human review |
|---|---|---|---|---|---|---|
| #52–#66 (15 PRs) | ~190 total | ~2,180 total | 0 | – | 23–34 h, merged in 14 min | 1 comment (#61) |
| #67 | 0 | 7 | 0 | – | 1 m 45 s | none |
| #68 | 784 | 1,056 | 0 | rename + encrypt | 11 h 51 m | none |
| #69 | 25 | 160 | 9 | – | 3 h 14 m | none |
| #79 | 177 | 214 | 701 | – | 2 m | none |
| #80 | 178 | 453 | 27 | irreversible | 23 m | none |
| #81 | 96 | 322 | 0 | – | 2 m | none |
| #82 | 87 | 260 | 0 | – | 2 m | none |
| #83 | 306 | 933 | 59 | 10 columns | 20 m | none |
| #84 | 288 | 953 | 15 | – | 2 m 30 s | none |
| #85 | 70 | 624 | 5 | – | 2 m 40 s | none |
| #86 (closed) | 2,282 | 7,498 | 959 | 251 lines | – | – |
| #87 | 30 (−151) | 184 | 0 | – | ~9 h | none recorded |
