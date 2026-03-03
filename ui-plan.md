# UI Design System Plan

Date: February 27, 2026  
Repo: `/Users/pablo/code/watergun`

## Goal
Create a single, enforceable UI system so future work (human or agent) produces consistent screens by default.

## Scope
In scope:
- Rails ERB views and shared partials
- Tailwind component layer in `app/assets/stylesheets/application.css`
- UI helper APIs in `app/helpers/*`
- UI-related tests and CI guardrails
- Design system docs in-repo

Out of scope:
- Mailer templates
- API JSON responses
- Rebranding (new visual identity) beyond consistency and systemization

## Audit Snapshot

Full scan covered `76` ERB templates.

### Drift metrics
- `8` templates with inline `style=""`
- `10` templates with raw `<button>` usage
- `23` templates with at least one clear drift signal (inline style, raw button, hardcoded destructive color bundle, hardcoded gradient action bundle, legacy alias usage)
- `6` templates using legacy alias classes (`text-base-content/*`, `bg-base-200`, `divide-base-300`, `text-neutral-500`, `btn link`)
- `16` templates using `submit_button` helper

### Existing system usage (partial)
- `page-shell` used in 19 templates
- `page-header` used in 11 templates
- `form-card` used in 8 templates
- `resource-list` used in 2 templates
- direct `status_badge(...)` calls in 10 templates

### Foundation quality
- Design tokens and component classes exist in `app/assets/stylesheets/application.css`
- Helper layer exists (`UiHelper`, `FormsHelper`, `DropdownHelper`, `TabsHelper`)
- Helper usage is uneven (`submit_button` used; `page_header`, `dropdown`, `tab_link` effectively unused in views)
- `157` semantic classes defined in CSS; `23` appear unused (candidate cleanup)

### Structural risks found
- Parallel button systems:
  - CSS `.btn*` classes
  - Ruby `submit_button` class string
- Duplicate and stale views:
  - `projects/apps/edit.html.erb` duplicates `projects/apps/settings/show.html.erb`
  - `Projects::AppsController#edit` redirects to settings, so edit template is effectively legacy
- Likely stale route helper usage in templates:
  - `new_app_path`, `new_app_service_path`, `app_service_path`, `activity_app_path`
- Missing design docs referenced by project docs:
  - `docs/design-system.html`
  - `docs/design-tokens.md`

## Design System Target State

## 1. Contract, not convention
Create a small UI API surface and make it the only allowed way to build repeated UI patterns.

Required primitives:
- `ui_button`
- `ui_page_header`
- `ui_empty_state`
- `ui_list` and `ui_list_row`
- `ui_form_section` (header/body/footer)
- `ui_danger_zone`
- `ui_icon_button`
- `ui_back_link`

## 2. Hybrid Tailwind policy
Allowed:
- Inline utility classes for layout composition only (`grid`, `flex`, `gap`, container spacing, responsive layout)

Disallowed:
- Ad hoc visual bundles for repeated controls (buttons, badges, empty states, list rows, destructive actions)
- Inline `style=""` in ERB (except truly dynamic values with no class alternative)

## 3. One source of truth
- Keep semantic tokens in CSS
- Keep component API in helpers and shared partials
- Keep rendered examples and guidance in docs
- Enforce with CI checks

## Workstreams

## A. Foundation cleanup

Tasks:
- [ ] Remove or archive stale/legacy templates that are not in active flow
- [ ] Resolve legacy route helper usage in active templates
- [ ] Delete dead helper surfaces or wire them to real usage
- [ ] Remove unused semantic CSS classes after migration pass

Primary files:
- `app/views/projects/apps/edit.html.erb`
- `app/views/projects/apps/_menu.html.erb`
- `app/views/projects/apps/index.html.erb`
- `app/views/projects/services/index.html.erb`
- `app/helpers/tabs_helper.rb`
- `app/helpers/dropdown_helper.rb`
- `app/helpers/icons_helper.rb`
- `app/assets/stylesheets/application.css`

Exit criteria:
- No duplicate active screen templates
- No stale route helpers in active views
- Dead helpers/classes either removed or intentionally documented

## B. Component API consolidation

Tasks:
- [ ] Introduce `ui_button` helper for both submit and link/button actions
- [ ] Refactor `submit_button` to delegate to `ui_button` styles
- [ ] Standardize size and variant scale:
  - variants: `primary`, `secondary`, `ghost`, `danger`
  - sizes: `xs`, `sm`, `md`
- [ ] Add `ui_icon_button` and use for edit/delete/icon-only actions
- [ ] Add `ui_page_header` helper + shared partial with title/subtitle/actions slots
- [ ] Add `ui_empty_state` helper + partial
- [ ] Add `ui_back_link` helper

Primary files:
- `app/helpers/ui_helper.rb`
- `app/views/shared/_page_header.html.erb`
- new `app/views/shared/ui/*.html.erb`
- `test/helpers/ui_helper_test.rb`

Exit criteria:
- One button styling API for submit + link + button actions
- Shared page headers and empty states used in active feature pages

## C. Pattern standardization

Tasks:
- [ ] Canonical list container and list row patterns:
  - status row list
  - action menu row
  - key/value row
- [ ] Canonical settings section shell:
  - title/subtitle/actions
  - content card
  - footer actions
- [ ] Canonical danger zone pattern
- [ ] Canonical modal trigger pattern (no raw `onclick`)
- [ ] Canonical log panel pattern

Primary files:
- `app/assets/stylesheets/application.css`
- shared UI partials under `app/views/shared/ui/`
- selected feature partials migrated to these patterns

Exit criteria:
- Deployments, domains, env vars, storage, services all use same list shell language
- Danger zones and empty states have one visual pattern

## D. Page-family migration backlog

Priority legend:
- P0 critical consistency blocker
- P1 high-value consolidation
- P2 cleanup polish

### P0: Highest drift, active workflows

1. Settings resource pages
- Files:
  - `app/views/projects/apps/env_variables/index.html.erb`
  - `app/views/projects/apps/domains/index.html.erb`
  - `app/views/projects/apps/storage_mounts/index.html.erb`
- Issues:
  - inline heading styles
  - raw modal trigger buttons
  - duplicated empty-state markup
- Action:
  - migrate to `ui_page_header`, `ui_empty_state`, standardized modal trigger helper

2. Service pages
- Files:
  - `app/views/projects/services/index.html.erb`
  - `app/views/projects/services/show.html.erb`
  - `app/views/projects/services/edit.html.erb`
- Issues:
  - hardcoded red classes
  - custom ad hoc action styles
  - inconsistent list/card patterns
- Action:
  - adopt `ui_button` and `ui_danger_zone`, normalize list rows and action patterns

3. Deployment detail + activity detail back links
- Files:
  - `app/views/projects/apps/deployments/show.html.erb`
  - `app/views/server_actions/show.html.erb`
- Issues:
  - inline styles
  - back links via button class plus inline padding
- Action:
  - replace with `ui_back_link` and log panel class tokens

4. Authentication screens consistency
- Files:
  - `app/views/sessions/new.html.erb`
  - `app/views/first_runs/edit.html.erb`
- Issues:
  - sessions uses raw submit button instead of shared button helper
- Action:
  - convert to unified form and button primitives

### P1: Core screens and shared components

1. App overview + deployment summary pattern mismatch
- Files:
  - `app/views/projects/apps/show.html.erb`
  - `app/views/projects/apps/deployments/_deployment_row.html.erb`
  - `app/views/projects/apps/deployments/_deployment.html.erb`
- Action:
  - pick one deployment row pattern and reuse across overview/index

2. Shared modal/pagination/toast controls
- Files:
  - `app/views/shared/_modal.html.erb`
  - `app/views/shared/_pagination.html.erb`
  - `app/views/shared/_toast.html.erb`
- Action:
  - ensure explicit button types
  - use `ui_icon_button` where appropriate
  - align interaction and size scale

3. GitHub settings action buttons
- File:
  - `app/views/accounts/github/_settings.html.erb`
- Action:
  - replace hardcoded button bundles with semantic variants

4. Metrics alias cleanup
- Files:
  - `app/views/metrics/_stats.html.erb`
  - `app/views/metrics/_cpu_chart.html.erb`
  - `app/views/metrics/_memory_chart.html.erb`
- Action:
  - replace legacy alias classes with primary semantic tokens

### P2: Legacy cleanup and polish

1. Remove duplicate legacy template
- `app/views/projects/apps/edit.html.erb`

2. Resolve stale route helper templates
- `app/views/projects/apps/index.html.erb`
- `app/views/projects/apps/_menu.html.erb`
- `app/views/projects/services/index.html.erb` (path helper checks)

3. Reduce unused CSS helper classes (after migration)
- `app/assets/stylesheets/application.css`

4. Icon helper adoption or pruning
- `app/helpers/icons_helper.rb`

## E. Documentation and contribution rules

Tasks:
- [ ] Create `docs/design-system/README.md`
- [ ] Create `docs/design-system/components.md`
- [ ] Create `docs/design-system/patterns.md`
- [ ] Create `docs/design-system/migration-guide.md`
- [ ] Update `CLAUDE.md` references to real files

Document content requirements:
- Allowed/forbidden patterns with examples
- Component API signatures and variants
- Accessibility defaults
- "How to add a new UI pattern" process
- Agent checklist for every UI PR

## F. Guardrails and CI

Tasks:
- [ ] Add script: `script/check-ui-consistency` (or equivalent)
- [ ] CI checks:
  - fail on inline style attributes in ERB
  - fail on forbidden ad hoc button bundles
  - fail on new raw `<button>` without explicit `type`
  - optional warning for legacy alias classes
- [ ] Add temporary allowlist file for phased migration

Suggested check patterns:
- `style=\"`
- `<button(?![^>]*\\btype=)` (PCRE)
- hardcoded bundles like `from-accent to-accent-hover`
- hardcoded destructive reds outside semantic classes

## G. Testing plan

Current constraint:
- UI lacks browser-level regression tests.
- Runtime command checks are currently blocked by Ruby mismatch (`3.4.4` installed vs `3.4.7` required in Gemfile).

Tasks:
- [ ] Add/expand helper tests for new UI helper APIs
- [ ] Add integration assertions for key screens (headers, actions, nav, empty states)
- [ ] Add at least one system-level smoke test for major navigation paths once Ruby runtime is aligned

## Milestones and sequencing

Milestone 0: Setup and cleanup
- finalize API contract
- remove/flag stale templates
- align runtime for test execution

Milestone 1: Core primitives
- `ui_button`, `ui_page_header`, `ui_empty_state`, `ui_danger_zone`, `ui_back_link`

Milestone 2: P0 migrations
- settings resource pages + service pages + deployment/activity detail + auth screens

Milestone 3: P1 migrations
- app overview/deployment unification + shared partial cleanup + GitHub settings + metrics alias cleanup

Milestone 4: Guardrails and docs
- docs finalized
- CI checks enabled
- migration allowlist reduced to zero

## Estimated effort

Total: `6-8` engineering days

Breakdown:
- Foundation cleanup: `0.5-1.0` days
- Component API consolidation: `1.0` day
- P0 page migration: `2.0-3.0` days
- P1 page migration: `1.5-2.0` days
- Guardrails + docs + tests: `1.0-1.5` days

## Definition of done

- No inline styles in active ERB views
- No ad hoc repeated control styling in active ERB views
- One button system (submit + link + button)
- Settings resource pages share one shell pattern
- Deployments list pattern is unified across app screens
- Danger zones and empty states are standardized
- Stale/duplicate templates removed or explicitly quarantined
- Docs exist in-repo and are referenced correctly
- CI checks prevent regression

## Next Session Kickoff Checklist

1. Read this file fully.
2. Confirm target API signatures for new helpers.
3. Create `docs/design-system/README.md` first (source of truth before edits).
4. Implement `ui_button` consolidation and update tests.
5. Migrate P0 pages in one vertical slice:
   - env vars
   - domains
   - storage
6. Run and fix tests.
7. Commit with clear phase labels.

## Suggested branch strategy

- `codex/ui-system-phase-0-cleanup`
- `codex/ui-system-phase-1-primitives`
- `codex/ui-system-phase-2-settings-pages`
- `codex/ui-system-phase-3-services-and-details`
- `codex/ui-system-phase-4-guardrails-docs`

