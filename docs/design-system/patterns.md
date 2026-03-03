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

Use `ui_page_header` for title/subtitle/action composition.

### Empty state

Use `ui_empty_state` with action slot when the user can recover.

### List shell

Use one of these shells consistently:
- `resource-list` for row links
- `card bg-elevated divide-y divide-border` for row collections

### Deployment rows

Use `projects/apps/deployments/_deployment.html.erb` as the canonical deployment row partial.

### Settings sections

Use settings layout + `ui_page_header` + content card(s) + semantic actions.

### Danger zone

Use `ui_danger_zone` and `ui_button variant: :danger`.

### Modal trigger

Use `ui_modal_trigger` (Stimulus-backed) instead of inline `onclick`.

### Log panel

Use semantic tokens:
- `.log-panel`
- `.log-panel-content`
- `.log-panel-content-relaxed`

## Examples

Preferred:

```erb
<%= ui_page_header(title: "Domains", subtitle: "2 configured") do %>
  <%= ui_modal_trigger "+ Add Domain", modal_id: dom_id(@app, :domain_modal) %>
<% end %>
```

Not allowed:

```erb
<button onclick="domain_modal.showModal()" class="btn btn-primary btn-sm">+ Add Domain</button>
```
