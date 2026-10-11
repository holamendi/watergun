# Watergun UI Design System

This document is the UI contract for Rails ERB screens in this repository.

## Docs

- `components.md`: component/helper API signatures and usage
- `patterns.md`: canonical layout/pattern rules and allowed/forbidden examples
- `migration-guide.md`: migration process and UI PR checklist

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

### `button`

```ruby
button(text = nil, href: nil, variant: :primary, size: :md, type: :button,
  class: nil, data: {}, method: nil, disabled: false, turbo_submits_with: nil,
  **options, &block)
```

- Variants: `:primary`, `:secondary`, `:ghost`, `:danger`
- Sizes: `:xs`, `:sm`, `:md`
- `href:` renders a link; no `href:` renders a `<button>`.

### `submit_button`

```ruby
submit_button(text, variant: :primary, size: :sm, **options)
```

- Delegates to `button`.
- Uses `type="submit"` and default Turbo loading text with spinner.

### `icon_button`

```ruby
icon_button(label:, href: nil, icon: nil, variant: :ghost, size: :sm,
  type: :button, class: nil, data: {}, **options, &block)
```

- Icon-only control with required accessible label.
- Accepts icon via `icon:` string/safe HTML or block.

### `page_header`

```ruby
page_header(title:, subtitle: nil, actions: nil, &block)
```

- Renders consistent page title/subtitle/actions shell.

### `empty_state`

```ruby
empty_state(title:, body: nil, icon: nil, actions: nil, &block)
```

- Standard card for empty collections.

### `danger_zone`

```ruby
danger_zone(title:, description:, actions: nil, &block)
```

- Standard destructive section shell.

### `back_link`

```ruby
back_link(text, path, **options)
```

- Canonical compact back navigation link.

### `modal_trigger`

```ruby
modal_trigger(text = nil, modal_id:, variant: :primary, size: :sm, **options, &block)
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

## Configuration controls

Settings use `config_action(text, variant: :primary, icon: nil, label: nil,
type: :button, **options)` rather than repeating button classes. Pass
`type: :submit` for saves; links preserve `href`, Turbo method/confirmation
and lazy-frame data. `config_modal_trigger(text, modal_id:)` opens inline
dialogs. `config_close_button` retains native `form method="dialog"` closure.
`config_modal_footer(submit:, variant: :primary)` renders an explicit Cancel
button (`dialog#close`) and scoped submit aligned at the end of the form.

Desktop configuration controls are explicitly 32px high; icon buttons are
32px square with 16px SVGs, independent of glyph metrics. On mobile (≤640px),
primary Save/Add controls are 44px high. Secondary, danger and icon controls
remain visibly 32px high, with 6px reserved margin and a pointer-active
pseudo-element extending 6px on every side: **44px hit area, 32px visible
footprint**. No text/icon scaling or enlarged filled Cancel. Do not remove
these margins or place overlapping controls in the reserved hit area.
Menu items and restart-option labels use actual 44px row targets on mobile.

`row_actions(id:, label:) { ... }` shares a native button trigger, unique
`aria-controls`, `aria-haspopup="menu"`, and live `aria-expanded`. Its block
contains buttons/links with `role="menuitem"` and `tabindex: -1`. A manual
native popover places menus in the top layer (not clipped by rows/cards).
The Stimulus controller handles Enter/Space, arrows, Home/End, Escape,
Tab, outside click, resize/scroll, disconnect and Turbo before-cache.
Opening focuses the first/last visible item; Escape and action selection
restore trigger focus (a subsequently opened native dialog owns focus).
Do not add unsupported Domain/Mount edit routes. Destructive links retain
Turbo confirmations; storage detach requires its existing action dialog.

Variable reveal/hide stays scoped to one row. Copy announces success only
when clipboard writing resolves and announces failure when unavailable or
denied. Existing lazy Turbo add/edit forms and successful close/replace
responses remain unchanged. General settings retain three independent
forms/saves, never a global Save or invented unsaved state.
