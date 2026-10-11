# Settings UI consistency screenshots

These are captures of the real Rails application using an isolated test database and nonsecret fixtures—not a prototype or a deployed environment.

Each comparison shows **desktop 1280px** on the left and **mobile 390px** on the right. `mobile-320.png` additionally shows all four settings screens at 320px. The labels outside the screenshots are review annotations, not application UI.

## Screens

- `general.png`: independent App Name, Repository and Builder saves, plus confirmed danger action.
- `domains.png`: Domains list and Add action.
- `domains-menu.png`: Set as default and confirmed Delete actions.
- `domains-modal.png`: native Add Domain dialog with shared Cancel/Submit footer.
- `env.png`: masked variable rows and Add action.
- `env-menu.png`: Reveal, Copy, lazy Edit and confirmed Delete actions.
- `env-modal.png`: Add Variable dialog.
- `env-edit.png`: lazy Edit Variable dialog with readonly name and nonsecret example value.
- `storage.png`: mount paths, statuses and row actions.
- `storage-menu.png`: action menu for existing mount operations.
- `storage-modal.png`: Add Mount dialog with action-local restart option.
- `storage-detach.png`: explicit keep-data detach confirmation dialog.
- `storage-reattach.png`: retained-mount reattachment dialog.
- `service.png`: service name-only Save, nonsecret Connection Copy and confirmed Delete at 1280/390px.
- `service-mobile-320.png`: service Settings at 320px, including visible active tab and separate type/version metadata.
- `mobile-320.png`: narrow mobile General, Domains, Variables and Storage screens.

Browser verification is implemented in `test/system/settings_browser_test.py`; see `docs/design-system/components.md` for its invocation and environment notes. Source captures and TDD/check logs remain in the task's scratch artifacts.
