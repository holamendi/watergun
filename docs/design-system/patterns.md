# Patterns

This document defines canonical page-level UI patterns.

## Allowed vs Forbidden

Allowed:
- Layout utilities for composition (`flex`, `grid`, `gap`, responsive wrappers)
- Semantic helper calls for repeated controls
- Shared partials for repeated shells (header, empty state, danger zone)

Forbidden:
- Inline `style=""` for static values
- Inline `onclick` handlers in ERB
- New hardcoded gradient/destructive button bundles in templates
- Copy-pasted empty-state/list/danger-zone markup across screens

## Canonical Patterns

### Page header

Use `page_header` for title/subtitle/action composition.

### Empty state

Use `empty_state` with action slot when the user can recover.

### List shell

Use one of these shells consistently:
- `resource-list` for row links
- `card bg-elevated divide-y divide-border` for row collections

### Deployment rows

Use `projects/apps/deployments/_deployment.html.erb` as the canonical deployment row partial.

### Settings sections

Use settings layout + `page_header` + content card(s) + semantic actions.

- Configuration Add/Save controls use `config_action` or `config_modal_trigger`.
- Place `config_modal_footer` inside each Domain/Variable/Storage form; Cancel
  closes the containing native dialog, never submits the form.
- Place `row_actions` inside the replaceable row root. Menu items are native
  buttons/links for existing routes only. Keep action dialogs in that same root
  when broadcasts replace the row; never portal row dialogs outside it.
- Keep General App Name, Repository and Builder forms independent, with a
  `config-form-footer` at the end of each form. Do not add a global Save.
- Service Settings retain a name-only form and `config-form-footer`; use the
  exact `service_form` ID required by the existing Turbo replacement response.
  Connection Copy is independently scoped, and Delete retains confirmation.
  Use the shared `settings-section` spacing rather than a separate layout.
- Mobile compact controls reserve their expanded hit areas in normal layout.
  Do not remove margins, overlap targets, or scale text/SVGs.
- See `components.md` for exact geometry, keyboard and Turbo contracts.

### Danger zone

Use `danger_zone` and `button variant: :danger`.

### Modal trigger

Use `modal_trigger` (Stimulus-backed) instead of inline `onclick`.

### Log panel

Use semantic tokens:
- `.log-panel`
- `.log-panel-content`
- `.log-panel-content-relaxed`

## Examples

Preferred:

```erb
<%= page_header(title: "Domains", subtitle: "2 configured") do %>
  <%= modal_trigger "+ Add Domain", modal_id: dom_id(@app, :domain_modal) %>
<% end %>
```

Not allowed:

```erb
<button onclick="domain_modal.showModal()" class="btn btn-primary btn-sm">+ Add Domain</button>
```
