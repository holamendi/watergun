# Components

This reference defines the approved UI helper and partial API for Rails ERB.

## Helper APIs

All helpers live in `app/helpers/ui_helper.rb`.

### `ui_button`

```ruby
ui_button(text = nil, href: nil, variant: :primary, size: :md, type: :button,
  class: nil, data: {}, method: nil, disabled: false, turbo_submits_with: nil,
  **options, &block)
```

- Variants: `:primary`, `:secondary`, `:ghost`, `:danger`
- Sizes: `:xs`, `:sm`, `:md`
- Use `href:` for links and omit it for button elements.
- Use `method:` for non-GET link actions.

Example:

```erb
<%= ui_button "Save" %>
<%= ui_button "Delete", href: project_path(@project), method: :delete, variant: :danger, size: :sm %>
```

### `submit_button`

```ruby
submit_button(text, variant: :primary, size: :md, **options)
```

- Delegates to `ui_button`.
- Includes Turbo submit loading content by default.

### `ui_icon_button`

```ruby
ui_icon_button(label:, href: nil, icon: nil, variant: :ghost, size: :sm,
  type: :button, class: nil, data: {}, **options, &block)
```

- Icon-only button, required `label:` for accessibility.

### `ui_page_header`

```ruby
ui_page_header(title:, subtitle: nil, actions: nil, &block)
```

- Standard page header shell for title/subtitle/actions.

### `ui_empty_state`

```ruby
ui_empty_state(title:, body: nil, icon: nil, actions: nil, &block)
```

- Standardized empty-state card.

### `ui_danger_zone`

```ruby
ui_danger_zone(title:, description:, actions: nil, &block)
```

- Standardized destructive action container.

### `ui_back_link`

```ruby
ui_back_link(text, path, **options)
```

- Canonical compact back link.

### `ui_modal_trigger`

```ruby
ui_modal_trigger(text = nil, modal_id:, variant: :primary, size: :sm, **options, &block)
```

- Canonical modal trigger using Stimulus (`dialog-trigger`).

## Shared UI Partials

- `app/views/shared/ui/_page_header.html.erb`
- `app/views/shared/ui/_empty_state.html.erb`
- `app/views/shared/ui/_danger_zone.html.erb`

## Shared Controls

- `app/views/shared/_modal.html.erb`
- `app/views/shared/_pagination.html.erb`
- `app/views/shared/_toast.html.erb`

These controls should use semantic UI helpers (`ui_button` / `ui_icon_button`) instead of raw ad hoc bundles.

## Accessibility Defaults

- All icon-only actions must use `ui_icon_button(label: ...)`.
- All raw `<button>` tags must include explicit `type`.
- Toasts must keep dismiss controls keyboard accessible.
- Back links and modal triggers should remain semantically links/buttons (not non-interactive elements with click handlers).
