# Corrective API compatibility and cutover

This is a rollout constraint, not authorization to deploy. The corrective PR must
remain open for Pablo's inspection. Issues #77/#78 and real Dokku verification
remain separate; transport-mocked tests do not prove a live deployment.

## Additive defaults

- env_variables.managed defaults to false, including existing locally authored,
  imported, external, synced and otherwise ambiguous rows. Only an allowed
  explicit write claims its named key. Do not backfill from timestamps, protection
  flags, remote pulls or archived encrypted action payloads.
- apps.env_generation defaults to zero. New desired writers increment it while
  holding app→project locks before child rows. PullEnv takes a checkpoint before
  SSH and discards observations invalidated by a newer write. No network under
  those row locks; pending mismatches and explicit discard tombstones survive.
- server_action_runs.finalized_at defaults to NULL. Existing action keys, payload
  ciphertext, resource/run IDs, idempotency HMAC namespace/canonicalization and
  queued payload interpretation are unchanged. Keep the encryption keys needed
  to read historical payloads. No payload migration or historical job execution
  is needed to add these columns.
- A remote_completed_at marker without finalized_at is repair-required, even if
  legacy recovery wrote status=success. Do not infer finalization from that status
  or mass-backfill success. Legacy successes without remote markers retain their
  historical status; stranded claimed work without evidence remains uncertain.
- github_events.pending_app_ids defaults to NULL. Only newly routed/retried events
  receive a durable target snapshot. The new recovery scheduler selects non-NULL
  pending lists, never every historical unprocessed event. Existing deployments
  with github_event_id identify accepted targets; old deployments without that
  linkage cannot be retrospectively deduplicated safely.

## Before separately authorized rollout

1. Stop/drain old application writers and workers before enabling these meanings.
   Mixed old writers do not increment generation/claim ownership; old workers can
   misreport completion, ignore repair exclusion and drop busy webhook fan-out.
   Their former Current protocol is not a compatible in-process calling interface.
2. Inventory already accepted queued replace operations before executing them.
   Their encrypted `unset` lists may already contain imported/unknown names.
   The new ownership column does not repair those decisions. An operator must
   inspect intent and authorize verified cancellation/replacement if needed;
   do not automatically rewrite, replay or cancel accepted production work.
3. Inspect remote-completed legacy runs for unfinished domains/link preparation,
   local deletion or other required finalization. They intentionally block new
   conflicting work. Recovery does not replay SSH or arbitrary succeeded! hooks.
   The narrow repair_delete! method verifies confirmed app deletion and immutable
   target identifiers, then performs only local deletion/finalization atomically.
   Other repairs require an inspected action-specific correction, not a generic
   success flag. Uncertain remote work has no automatic retry permission.
4. Inventory legacy webhook events before any explicit redelivery. An old event
   may have partially accepted work without deployment linkage. Do not blindly
   feed the historical backlog into the new per-target fan-out.
5. Apply additive migrations, boot only the new revision and scheduler, and verify
   pending dispatch and deferred-target recovery in the authorized environment.
   Never execute historical queued work merely as a migration validation step.

## Rollback and roll-forward

Prefer roll-forward. Keep the additive data if reverting application code; older
code ignores provenance/finalization and can reintroduce the destructive behavior.
Pause writers/workers before any rollback and independently prove compatibility
before resuming. A down migration drops evidence and is not a safe live recovery
procedure. No production backfill, inventory, cancellation, worker cutover,
rollback, deployment or data cleanup was performed by this PR.

The app-scoped conflict policy is not a redesign of every preexisting
project/service/domain/storage parent-child race. Only the reproduced env,
CreateServiceLink lock order and current UI protection seams are corrected here.
