# Persistent app storage

Storage is managed from an app's **Settings → Storage** page. Adding a mount, detaching it, reattaching it, or retrying an operation restarts the app and may interrupt requests.

## Paths and data

- New or changed container paths must be absolute, normalized, non-root paths. Components may contain letters, numbers, underscores, hyphens and dots, but cannot be `.` or `..`. Spaces, shell metacharacters, colons, trailing slashes and repeated separators are rejected.
- New mounts receive a stable, unique directory directly beneath `/var/lib/dokku/data/storage`, named `watergun-<random identifier>`. Users cannot supply a host path.
- Mounting hides the image's existing files at the container path. Those files are **not copied** into the storage directory.
- **Detach (keep data)** removes the binding and retains both its database record and backing files. **Reattach** uses the same path and ownership choice.
- A detached record still reserves its container path. Reattach it rather than adding another mount at the same path.
- **Deleting the app is different from detach:** app deletion destroys its storage metadata through `dependent: :destroy`, but does not remove the backing bytes. Keep a record of the exact host paths and arrange operator cleanup or recovery; the deleted app's mounts can no longer be reattached through this UI.
- Unchanged legacy container paths (including trailing slashes) remain usable for status transitions, retries, detach and reattach. They are not normalized or renamed. Existing legacy host paths are preserved. Reattachment checks that their exact directory already exists; it does not create a different directory or move data. Missing legacy directories need operator investigation.

## Ownership

Builder defaults remain Herokuish (`32767:32767`) and Nixpacks/Heroku (`1000:1000`). Dockerfile apps can explicitly select one of Dokku's supported ownership presets: `1000:1000`, `2000:2000`, or `32767:32767`. Select the preset matching the image's runtime user. Keeping ownership passes `--chown false` explicitly, rather than silently applying Dokku's Herokuish default.

The installed Dokku **0.36.7** storage plugin does not accept arbitrary numeric UID:GID values. Its privileged ownership helper permits only IDs 1000, 2000 and 32767. Watergun therefore does not offer arbitrary IDs, use a privileged Docker workaround, or modify server permissions. Images using other IDs need an operator-supported ownership approach outside this feature. Ownership presets recursively affect only this mount's generated directory when it is ensured.

## Lifecycle and retries

New mounts are `pending`; detach requests are `detaching`. Storage operations use `StorageServerActionJob` with immediate enqueue and explicit enqueue-success checking inside the lifecycle transaction. Solid Queue shares the primary Active Record connection pool (`config.solid_queue.connects_to = nil`); merely pointing two pools at the same database is not atomic. A failed enqueue rolls back both the lifecycle change and action, leaving the request retryable. Keep this shared-pool configuration; separate queue databases require a durable outbox/recovery design. Other jobs retain their after-commit enqueue behavior.

The worker reads both configured phases through `sudo -n dokku plugin:trigger storage-list <app> deploy json` and the corresponding `run` trigger. Dokku 0.36.7's public `storage:list` only reads deploy, and `plugin:trigger` is root-only. The existing Watergun installer already grants its SSH user passwordless sudo; list commands use `sudo -n` and fail retryably if that permission is unavailable. It reconciles each missing/present exact binding with `docker-options:add`/`docker-options:remove` for that individual phase, leaving unrelated bindings alone. Remove arguments are escaped for Dokku's sed basic regex as well as for the shell. This repairs a previous attempt that changed deploy but failed before changing run. After restarting, it reads and verifies **both** phases before marking the record `active` or `detached`.

Mount errors are shown as **Mount failed; state unconfirmed**; detach errors as **Detach failed; state unconfirmed**. A failed restart may mean the binding changed but the running app did not, so neither error is presented as a successful state. **Retry mount** or **Retry detach** preserves the original operation intent, rereads Dokku, and retries the restart and verification. Connection setup failures also mark the operation retryable. Duplicate requests while an operation is pending/running are rejected.

The phase lists verify Dokku's configured deploy and run bindings. Successful restart plus phase-list verification is not an independent inspection of every live container. Operator smoke testing should inspect the actual container mount and writable files as well.

## Local Dokku-in-Docker storage

The Compose Dokku service talks to the host Docker daemon. A bind mount therefore resolves its source on the host, not inside the Dokku container. Compose binds `/var/lib/dokku/data/storage` on the host to Dokku's persisted storage location at `/mnt/dokku/var/lib/dokku/data/storage`, so directory creation, ownership changes and app mounts refer to the same files. This was exercised on the Linux local development host with Dokku 0.36.7. The directory remains after container recreation and `docker compose down -v`; it is not a Compose named volume and requires explicit operator backup/removal. `bin/local-dokku reset` does not erase these backing directories.

**Existing local installations:** before applying the new bind, inspect and back up both the old named-volume storage directory and the host directory. The bind hides the old directory inside the Dokku volume; it does not migrate or delete it. Compare any overlapping paths and migrate retained files with ownership preserved while apps are stopped, without overwriting newer host data. Do not assume a successful restart proves an existing local installation has been migrated. Bare-host Dokku servers do not need this Compose change.

Local ports default to loopback and can be set with `LOCAL_BIND_ADDRESS`, `DOKKU_HTTP_PORT` and `DOKKU_HTTPS_PORT`. The Dokku service uses the default Docker bridge to reach its spawned apps. When changing the checkout directory, use Compose project `watergun` (`docker compose -p watergun ...`, as `bin/local-dokku` does) to reuse the existing named volumes.

## Operator smoke test

Use an expendable app and a dedicated generated mount. Do not delete backing data.

1. Choose a container path that does not overlap other mounts; choose a supported owner matching the runtime user.
2. Add storage in the UI. Confirm the operation log contains both `plugin:trigger storage-list` phases, `storage:ensure-directory --chown <preset> <exact-directory>`, phase-specific `docker-options:add`, `ps:restart`, and final lists for both phases.
3. Confirm the UI reaches `active`. Inspect `sudo -n dokku plugin:trigger storage-list <app> deploy json`, the corresponding `run` list, and the live container's bind mounts. Confirm the host path exactly matches the record.
4. Write a marker into the container path as the app's runtime user. Redeploy or restart the app and verify the marker survives.
5. Detach through the UI. Confirm `detached`, no configured/live binding, retained record, and the marker still present in the backing directory.
6. Reattach. Confirm the original host path and marker reappear and remain writable.
7. In a controlled test environment, simulate a failed restart after the binding change. Confirm the error is visible, retry does not fail on an already mounted/absent binding, and the correct operation reaches its verified state.
8. Capture the UI and logs for the PR. No app/server credentials or public ingress are needed for this test.

Historical records already destroyed by the previous unmount implementation cannot be restored by this change. There is no data deletion, backup, shared-volume, or arbitrary host-path functionality.
