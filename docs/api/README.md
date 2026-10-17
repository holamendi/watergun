# Watergun v1 public API contract

Status: target contract for issues #71–#78, not a claim that those features are
already implemented. At the #71 milestone only GET /api/v1/apps, GET
/api/v1/apps/:id, the nested deployment GET routes, and the nested ping exist.
No production rollout is authorized by this document. The executable workflow
requires the complete release; #78 must prove it against isolated real Dokku.

At #74, GET /api/v1/operations/:id is implemented for accepted public operations.
Mutation HTTP controllers remain deferred to #75/#76. Their shared Ruby boundary
is ServerAction::Accept.call(token:, endpoint:, target:, key:, request:,
request_id:, scope:) { |locked_target| ... }, returning exactly one newly
enqueued ServerActionRun from the existing domain call. Pass validated logical
JSON with defaults expanded, a fixed method/route identity, a Project/App reference
and the server-generated request ID; never pass raw controller parameters. The
boundary owns commit (no enclosing caller transaction), locks/revalidates token,
membership and target context, and atomically stores the domain preparation,
encrypted run, HMAC fingerprint/key identity, audit IDs and dispatch obligation.
An App.new(id: id) reference allows replay before resolving a deleted target;
only an original authorized acceptance can replay, and fresh work must resolve a
live owned target. render_operation(run, status: :accepted) supplies the shared
202 envelope/Location; it does not itself perform or accept work.

## Reference and validation

openapi.yml is the machine-readable OpenAPI 3.1 reference. All paths include
/api/v1. JSON Schema components can be reused directly by HTTP contract tests.
Install the repository's test bundle, then run:

    bundle exec ruby script/check-api-contract
    printf '%s' '{"mode":"merge","values":{"GREETING":"hello"}}' | bundle exec ruby script/check-api-contract EnvWrite
    bin/rails test test/contracts/public_api_contract_test.rb

The checker validates the OpenAPI document offline and optionally validates JSON
from stdin against a named component. It exits nonzero for invalid instances;
it deliberately never prints instance data or validator error objects. Schema
validity alone does not establish HTTP implementation compatibility. Request
integration tests and the #78 real deployment gate are separate requirements.

## Identity, ownership, scopes and token migration

HTTPS and Authorization: Bearer <opaque-token> are required. Never place a token
in a URL. There is no browser cookie fallback for public requests. A token has
one account and an owning user; personal/service tokens are managed by an
account member through authenticated, owner-scoped web token management (not a
public bearer-token self-escalation endpoint). Creation/rotation shows a secret
once. Listing exposes metadata only: numeric ID, name, scopes, expiry, revocation
and safe last-used timestamp. Revocation is immediate; rotation atomically revokes
the old token and issues a newly scoped token. New tokens expire within one year
and cannot receive scopes not explicitly requested. Stored secrets are digests,
not retrievable values. Token-management audit identifies actor, token ID and
mutation, never secret material. OAuth/project restrictions are deferred.

Scopes are conjunctive with account access and the read_only flag:

| Scope | Routes |
| --- | --- |
| apps:read | projects, app/deployment reads and nested ping |
| apps:write | create/delete/restart apps |
| deployments:write | create deployments |
| env:write | write environment configuration |
| operations:read | poll operations |
| logs:read | read deployment logs |

read_only rejects every mutation even if a write scope is present. Operations and
logs require their own read scopes, not write scopes. Issuance rejects unknown
scopes. Migrated legacy tokens retain the same presented secret and original
expiry/read_only policy, but receive only apps:read (their existing supported
routes); they do NOT silently gain new write, operation or log access. Migration
replaces plaintext with a digest without logging/copying it into audit records.
Owners explicitly issue/rotate a token with the required new scopes to use the
workflow. Expiry is exclusive: expires_at <= current time is invalid. Missing,
invalid, expired and revoked tokens all yield 401 without revealing which case.
Check current authorization even on idempotent replays, before returning stored
results. Revocation before execution must prevent not-yet-started API work;
revocation cannot undo work already running remotely.

Token management uses the existing signed browser session and Rails CSRF
protection, never bearer-only authentication. JSON routes (not `/api/v1`) are:
GET/POST /account/api_tokens, GET/DELETE /account/api_tokens/:id, POST
/account/api_tokens/:id/rotate, and POST /account/api_tokens/claim. Issuance and
rotation accept {"api_token":{"name":"automation","scopes":["apps:read"],
"read_only":true,"expires_at":"2027-01-01T00:00:00Z"}}; name and explicit scopes
are required. Omitted expiry defaults to one year, with issuance bounded to a
future instant within one year. Responses use api_token/api_tokens metadata;
only a successful 201 issuance/rotation also returns secret. Responses are
no-store. DELETE revokes instead of destroying history; repeating it is safe.
An invalid/failed rotation leaves the old token usable and creates no replacement.
Creation, claim, rotation and revocation audit rows commit with their mutation.

Historical tokens have no recorded owner. The migration leaves user_id NULL
rather than assigning an arbitrary account member. A signed-in account member
who already possesses the exact legacy secret can claim it with {"token":"..."}
at the claim endpoint, then list/revoke/rotate it. Claim returns metadata only,
preserves expiry/read_only/read-only scopes, and cannot transfer an owned token
or a foreign-account token. Newly issued tokens belong to the signed-in user;
other account members cannot list or manage them. Removing an owner's membership
invalidates their owned tokens. New bearer secrets use a high-entropy wg_ prefix;
legacy secrets are hashed as-is rather than normalized or regenerated.

Rollout prerequisite: drain/stop old application and worker processes before the
digest migration and restart only the new revision. Old code expects the removed
plaintext column. Digest conversion is intentionally irreversible: rollback
cannot recover original secrets, and no secret-bearing backup is created by the
migration. Historical backups/logs are not retroactively sanitized. This is a
deployment requirement, not authorization to deploy or alter production.

Every lookup starts at the authenticated account, including operation IDs,
log cursors and nested parent-child relationships. A wrong-account, missing,
deleted or wrong-parent ID yields indistinguishable 404. An authenticated token
with an insufficient scope yields 403 before resource disclosure. The historic
nested ping ignores the app ID, returning {"pong":true}; it is an authentication
probe, never existence/readiness evidence. This compatibility exception must not
be used to resolve an app or authorize a mutation.

## Context, sources and readiness

GET projects lists account projects with server_id. POST projects/:id/apps binds
the app to that project's persisted server; never use a browser-selected server
or the account's first server. Foreign IDs, discarded projects or inconsistent
account/server ownership must not be accepted. There is no server/project create
endpoint in the first release. A member must provision an accessible Dokku server
and project plus an authorized GitHub App installation before using this API.

AppCreate supports only source.type=github and a repository owner/name plus a
full branch name (including slashes). Public/private repositories are supported
only when accessible through the account's installation. Raw Git URLs, Docker
image sources, arbitrary SSH/Dokku commands, custom classes and caller-supplied
server credentials are not supported. App creation validates repository/branch
access before acceptance; it creates the remote app but does not deploy code.
Builder is herokuish (default), dockerfile or nixpacks, matching existing app
builders. The selected builder is applied before deploy. No arbitrary build
options, Dockerfile path overrides, webhook-deploy changes or source changes are
accepted in the first release.

DeploymentCreate {} resolves configured branch HEAD once; {"sha":"<40 hex>"}
resolves that commit in the configured repository once. The resolved commit is
pinned to the accepted deployment so a retry cannot deploy a newer branch HEAD.
No different repo/branch/builder is implicitly selected by a deployment request.
Missing/unusable server, project, installation, repo or builder prerequisites
produce 409 prerequisite_missing with a safe actionable message. An unavailable
GitHub dependency before durable acceptance yields 503 unavailable. Unknown
sources/invalid values yield 422 validation_failed. Unknown JSON fields and
malformed structures/headers/query values yield 400 invalid_request. There is
no success response implying prerequisites have been established externally.

Mutations require no other in-flight mutation on that app, including UI-driven
work. Pending app creation, deploy/restart/delete and env changes cannot overlap
incompatibly. Independent apps remain usable. A not-ready/busy app yields 409
operation_conflict; retrying a previously accepted identical key takes precedence
over this busy check. Restart requires a deployed, usable app. Delete may remove
a failed app for recovery; no delete during uncertain/in-flight remote work.

## JSON, errors, compatibility and pagination

IDs stay positive JSON integers/database IDs, never UUID replacements. Preserve
existing app/apps and deployment/deployments root wrappers and fields, including
nullable github_repo, successful deployment, timestamps, repo, sha and source.
Additional safe app status, project_id/server_id, url and env_names fields are
additive in the completed release. They must never contain deploy_token, env
values, internal action payloads, raw command strings or SSH/GitHub credentials.
Clients must tolerate additive response fields. App url may be null before a
public route is available. Deployment status remains pending/deploying/success/
error; public operation status is deliberately a different vocabulary.

Existing nested deployment route uses :id, not a new identifier type. There are
no top-level deployment routes on current main, despite old controller branches.
POST deployments was not routed on current main; adding it with 202 does not
replace an existing routed 201 response. Existing unauthorized responses may be
empty/plain-text; compatibility clients must accept those historical 401 bodies.
The completed release consistently returns ErrorEnvelope JSON. No current route,
root wrapper, attribute or numeric identifier is removed by this contract.

All list endpoints use page >= 1 and limit 1..100 (default 20), ascending numeric
ID order; GET logs instead uses its cursor. Invalid/out-of-range query values
return 400 rather than silently disabling bounds. An empty valid page is 200
with an empty array. Current-Page, Total-Pages (at least 1) and RFC 8288 Link headers
identify pages; follow rel=next, do not assume the first page is the entire
collection. Existing apps already paginates; existing deployment reads are
unbounded. The completed release explicitly changes deployment listing to these
bounds as a resource-safety compatibility change: clients must follow Link.
No pagination wrapper is added around existing JSON arrays. This change must be
covered by existing-consumer tests and called out in release evidence.

New project/operation/log timestamps are RFC 3339 UTC strings ending in Z, with
optional fractional seconds; not epoch numbers or local time. Existing Alba
app/deployment timestamps retain their legacy YYYY-MM-DD HH:MM:SS UTC strings
(LegacyTimestamp also accepts RFC 3339 for compatible clients). Do not silently
reformat the existing runtime output. Unstarted/unfinished timestamps are null.
X-Request-ID is server-generated for each HTTP attempt. ErrorEnvelope includes
the same request_id. Stored operation.request_id is the ORIGINAL acceptance ID;
a replay/poll has its own response header while preserving that original ID.
Incoming arbitrary IDs must not enable log injection or become audit identity.

Stable status/code pairs are listed in OpenAPI. Error messages are short safe
summaries; validation details are field/code pairs, never rejected values or
exception strings. 401 unauthorized, 403 forbidden, 404 not_found, 409
operation_conflict/idempotency_conflict/prerequisite_missing, 410 expired, 413
request_too_large, 415 unsupported_media_type, 422 validation_failed, 429
rate_limited and 503 unavailable have stable meanings. Unexpected errors are 500
internal_error with a request ID, never Rails traces or exception causes. JSON
bodies on POST/PUT require application/json. Restart/DELETE have no body.

## Durable operations, retry and recovery

Every mutation requires Idempotency-Key: 1..128 ASCII letters, digits or ._:-.
202 means the resource changes plus operation, request fingerprint and durable
dispatch responsibility committed atomically. A queued row alone is NOT dispatch
proof. Before 202 there must be durable queue insertion in the same database
transaction or a recoverable dispatch obligation. If acceptance cannot commit,
return 503, not a phantom operation. HTTP never waits for SSH/build completion.

Response {"operation":{...}} and Location: /api/v1/operations/:id identify accepted
work. Retry-After: 2 gives the minimum polling interval. GET operation returns
queued, running, succeeded or failed. Terminal errors include dispatch_failed,
remote_failed or outcome_unknown, not raw remote output. Poll state to completion;
202 and a deployed-looking local resource are NOT remote success. A failed create,
deploy or delete retains inspectable state. Reconciliation/bookkeeping failure
must not turn a committed remote success into a false remote failure.

Keys are scoped to account + issuing token ID + method + canonical route/target
(including parent ID). Rotate token => a different key namespace, not permission
to replay an old operation. Fingerprints use a canonical validated logical JSON
request: recursively sorted object keys, defaults expanded, and absent body for
restart/delete treated consistently. Env null and empty string remain distinct.
Fingerprints must be keyed digests so low-entropy secret values are not exposed
through plain hashes. Reuse with the same logical request returns the original
operation ID/envelope and Location with 202, even after completion; no second
local resource, deployment or remote command. Reuse with different payload yields
409 idempotency_conflict. Atomic unique constraints/locking must enforce this for
independent database connections, not just a process-local mutex.

Idempotency records and operation metadata are currently retained indefinitely,
including terminal keys. There is no expiry task or key recycling, so a restart
or the passage of 30 days cannot authorize a duplicate mutation. This conservative
policy exceeds the minimum 30-day terminal retention; clients must still never
reuse keys. A future bounded-retention change must preserve permanent key
tombstones or introduce a reviewed race-safe expiry protocol before recycling.
Queued/running keys never expire. Operations survive successful
app/deployment deletion with original numeric resource references and no dangling
credential payloads. Resource reads then yield 404; operation polling remains
available through retention. Owner-scoped operation tombstones may return 410 for
the next 30 days, then 404. Unknown/foreign tombstones are always 404.

Dispatch retries may recover queued work that has definitely not started. A
worker crash after claiming work or losing remote completion is outcome_unknown,
not permission to automatically replay a destructive SSH command. Reconcile or
require explicit operator recovery; retain conflict protection until uncertainty
is resolved. A crash/restart test must distinguish unsent from uncertain work.
No generic automatic job/HTTP retry may execute a second remote mutation.

The current configuration has no separate queue database: Solid Queue shares
the primary connection pool. Nevertheless acceptance stores dispatch_pending_at
on the same run transaction rather than depending on an after_commit callback.
The every-minute recover_server_actions recurring task invokes
ServerAction::Recovery.call after queue availability returns (also callable by
an operator after restart). A queued, unsent run is dispatched; a queued delivery
older than five minutes can be redelivered, with the existing atomic claim
preventing duplicate execution. Scheduling holds a transactional run lock; a
process death while scheduling rolls back uncommitted queue insertion and
enqueued_at together in the current shared-pool configuration. No standalone
dispatching state or lease is trusted as proof of remote completion.

Recovery takes the same resource advisory lock nonblocking. A live worker keeps
its lock, regardless of elapsed time. A stranded running run without a persisted
remote-completion marker becomes failed/outcome_unknown and retains app conflict
exclusion. It is never requeued; an operator must verify/reconcile remote state
before explicitly resolving uncertainty. This API does not provide an unsafe
"retry uncertain operation" endpoint. A persisted marker is written only after
the action's primary remote execution returns successfully, never at acceptance,
queueing or claim. A subsequent bookkeeping/notification/log/SSH-drain failure
cannot erase that evidence: terminal public status is succeeded (internal
diagnostics may record the bookkeeping error). A crash before the completion
marker commits remains unknown, not a guessed success. Failed pre-execution token
revalidation yields failed/authorization_failed; terminal dispatch validation
failure yields dispatch_failed. No exception text or command output is public.
Drain old workers before this migration/runner cutover: old binaries do not
participate in these acceptance/recovery guarantees. No rollout is authorized.

## Write-only configuration

PUT apps/:id/env accepts {"mode":"merge"|"replace","values":{NAME:string|null}}.
Merge preserves omitted keys; replace deletes omitted MANAGED keys. Null deletes
a named key (missing deletion is a no-op); "" sets an empty string, not deletion.
An empty merge is an accepted no-op; an empty replace removes all managed keys.
Only Watergun-managed user keys are affected: preserve service-link DSNs,
reserved/system variables and unmanaged remote values. User writes cannot edit
or remove service-managed names. DOKKU_ names, NUL bytes, invalid names, duplicate
JSON object keys and a mixed-validity batch are rejected before any local/remote
change. The complete HTTP body is limited to 64 KiB, with at most 100 keys, 128
characters per name and 16,384 per value. No partial validation acceptance.

Acceptance atomically records the whole desired batch in encrypted storage.
Remote application is one shared ordered command path; a remote failure is not
claimed to roll back Dokku atomically. Mark the operation failed with inspectable
safe state and require explicit reconciliation instead of automatic blind replay.
The endpoint returns only its operation; app metadata exposes sorted env_names,
never values. Writes require the shared app conflict gate. Env changes set the
existing pending-restart indication, and use no implicit remote restart; client
must deploy/restart explicitly. Plaintext values and reversible encodings must be
absent from persisted operations, logs, audit, diagnostics, instrumentation and
escaping exception causes, not just absent from JSON responses.

## Logs, audit and limits

Deployment logs use after (exclusive entry ID, initially 0) and limit 1..100
(default 50), ordered ascending. Each entry is at most 16,384 characters and each
page is at most 64 KiB UTF-8 text; split/truncate remote output safely and indicate
truncation with a system entry. next_cursor is the last included ID if further
entries exist, else null. complete=false on queued/running/incomplete logs;
complete=true only after final capture. An empty incomplete page is 200, never
false evidence of completion. Output capture need not be live/streaming.

Logs are redacted through the shared safe-output path before persistence/public
rendering. Logs never expose raw command payloads, env secrets, DSNs, bearer,
GitHub or SSH credentials. User application output may contain unknown secrets;
clients should avoid printing arbitrary log bodies into other systems. Log
access requires logs:read and account/parent ownership even for failed work.
Logs expire 30 days after terminal operation completion; retained owner-visible
resources yield 410 expired. Deleted app/deployment logs yield 404. Queued/running
logs do not expire; retained metadata declares expires_at (provisional while
running, extended on completion).

Audit stores actor user/token IDs, account/resource IDs, operation kind, original
request ID and timestamps, never request bodies, env values or bearer material.
It is distinct from operation payloads and public metadata. Logging/monitoring
must not resurrect secrets through exception causes, SQL binds or job arguments.

Release limits: 120 reads/minute/token (including polls/logs), 20 mutations/minute/
token, 30 invalid-token requests/minute/source IP, 64 KiB request bodies, the page
bounds above. Fixed 60-second windows must use a shared durable backend, not
per-worker counters. 429 includes Retry-After seconds until reset and a safe
rate_limited envelope. Independent tokens/tenants are not conflated. Authenticate
proxy client IP only through explicitly trusted proxy configuration; do not trust
arbitrary X-Forwarded-For. Invalid-token buckets never store/log bearer strings.

## Runnable target workflow

Prepare a safe test project/server and accessible GitHub repository first. Issue
a token with apps:read, apps:write, deployments:write, env:write, operations:read
and logs:read. Do not put a real token in shell history, script arguments or logs.
The example reads API_TOKEN from the environment; disable shell tracing. Set:

    export API_URL=https://your-authorized-test-watergun.example
    export PROJECT_ID=1 APP_NAME=api-disposable GITHUB_REPO=owner/test-repo
    export GITHUB_BRANCH=main APP_BUILDER=dockerfile
    export APP_ENV_JSON='{"GREETING":"hello"}'
    ruby script/api-workflow

The script creates/configures/deploys, repeats the identical deployment request
with the same key, inspects status/logs, restarts, and deletes, polling each
operation. It prints safe IDs and app_url, never token/env values or response
bodies. HTTP transport automatic retries/redirects are disabled. On failure it
stops and leaves evidence/resources inspectable rather than blindly retrying or
deleting uncertain work. Capture the printed app ID/run key for manual recovery;
a new invocation generates new keys and creates a new disposable app. It has a
bounded polling timeout and does not guess recovery after a process restart.

Do not claim release from the example's success alone. #78 additionally verifies
actual public HTTP content while the app exists, deliberate failed deployment
status/logs, post-delete remote cleanup and the exact real revision/environment.
No production database/volume edits or production app deployments are part of
this contract. Domains/SSL, storage, services, outbound webhooks, streaming logs,
OAuth, CLI/MCP and arbitrary build customization remain deferred.
