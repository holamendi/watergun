# Watergun UI Design System

This document is the UI contract for Rails ERB screens in this repository.

## Goals

- Keep the current Watergun visual language.
- Make repeated controls come from shared helper APIs and partials.
- Allow Tailwind utilities for layout composition only.

## Rules

Allowed:
- layout utilities (`flex`, `grid`, spacing, responsive wrappers)
- one-off structural wrappers for page composition

Disallowed:
- inline `style=""` for static styling
- new ad hoc button bundles in templates
- repeated empty-state/list/danger-zone markup copied per page

## Primitive API Contract

All helpers live in `UiHelper`.

### `ui_button`

```ruby
ui_button(text = nil, href: nil, variant: :primary, size: :md, type: :button,
  class: nil, data: {}, method: nil, disabled: false, turbo_submits_with: nil,
  **options, &block)
```

- Variants: `:primary`, `:secondary`, `:ghost`, `:danger`
- Sizes: `:xs`, `:sm`, `:md`
- `href:` renders a link; no `href:` renders a `<button>`.

### `submit_button`

```ruby
submit_button(text, variant: :primary, size: :md, **options)
```

- Delegates to `ui_button`.
- Uses `type="submit"` and default Turbo loading text with spinner.

### `ui_icon_button`

```ruby
ui_icon_button(label:, href: nil, icon: nil, variant: :ghost, size: :sm,
  type: :button, class: nil, data: {}, **options, &block)
```

- Icon-only control with required accessible label.
- Accepts icon via `icon:` string/safe HTML or block.

### `ui_page_header`

```ruby
ui_page_header(title:, subtitle: nil, actions: nil, &block)
```

- Renders consistent page title/subtitle/actions shell.

### `ui_empty_state`

```ruby
ui_empty_state(title:, body: nil, icon: nil, actions: nil, &block)
```

- Standard card for empty collections.

### `ui_danger_zone`

```ruby
ui_danger_zone(title:, description:, actions: nil, &block)
```

- Standard destructive section shell.

### `ui_back_link`

```ruby
ui_back_link(text, path, **options)
```

- Canonical compact back navigation link.

### `ui_modal_trigger`

```ruby
ui_modal_trigger(text = nil, modal_id:, variant: :primary, size: :sm, **options, &block)
```

- Standard modal-open trigger.
- Uses Stimulus (`dialog-trigger`) instead of inline `onclick`.

## Shared Partials

- `app/views/shared/ui/_page_header.html.erb`
- `app/views/shared/ui/_empty_state.html.erb`
- `app/views/shared/ui/_danger_zone.html.erb`

## Milestone 0 Cleanup Notes

- Legacy duplicate/stale templates are removed when not in active flow.
- Legacy route helper usage in active templates is replaced with project-scoped helpers.

## Testing Expectations

- Helper tests cover API signatures and variant/size mappings.
- Controller integration assertions cover key primitives on active pages.

## Guardrails

Guardrails script and CI checks are added after P0 page migrations are complete.
