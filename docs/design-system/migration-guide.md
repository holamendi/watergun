# Migration Guide

Use this process for any UI migration or new UI feature.

## Migration Steps

1. Identify repeated controls in target templates.
2. Replace repeated control markup with `UiHelper` primitives.
3. Replace repeated page shells with shared partials/patterns.
4. Remove inline `style` / `onclick` and ad hoc button bundles.
5. Add/update helper and integration assertions.
6. Run:
   - `script/check-ui-consistency`
   - relevant tests with `mise exec -- bin/rails test ...`

## PR Acceptance Criteria

- No new inline `style=""` in ERB.
- No inline `onclick=` in ERB.
- No new raw `<button>` without explicit `type`.
- New repeated controls implemented via helpers/partials.
- Tests updated for key UI behaviors.

## Adding a New UI Pattern

1. Confirm the pattern appears at least twice or is expected to repeat.
2. Add helper API in `UiHelper` and/or shared partial under `app/views/shared/ui/`.
3. Document signature and usage in `docs/design-system/components.md`.
4. Document placement rules in `docs/design-system/patterns.md`.
5. Add tests for helper output and at least one integration assertion.

## Agent Checklist (UI PR)

- Read `docs/design-system/README.md`.
- Use `ui_button`/`ui_icon_button` for actions.
- Use `ui_page_header` and `ui_empty_state` where applicable.
- Prefer `ui_modal_trigger` for dialog opens.
- Ensure destructive actions use `ui_danger_zone` + danger variant button.
- Run `script/check-ui-consistency`.
- Run relevant tests with `mise exec`.
