# Components

This reference defines the approved UI helper and partial API for Rails ERB.

## Helper APIs

All helpers live in `app/helpers/ui_helper.rb`.

### `button`

```ruby
button(text = nil, href: nil, variant: :primary, size: :md, type: :button,
  class: nil, data: {}, method: nil, disabled: false, turbo_submits_with: nil,
  **options, &block)
```

- Variants: `:primary`, `:secondary`, `:ghost`, `:danger`
- Sizes: `:xs`, `:sm`, `:md`
- Use `href:` for links and omit it for button elements.
- Use `method:` for non-GET link actions.

Example:

```erb
<%= button "Save" %>
<%= button "Delete", href: project_path(@project), method: :delete, variant: :danger, size: :sm %>
```

### `submit_button`

```ruby
submit_button(text, variant: :primary, size: :md, **options)
```

- Delegates to `button`.
- Includes Turbo submit loading content by default.

### `icon_button`

```ruby
icon_button(label:, href: nil, icon: nil, variant: :ghost, size: :sm,
  type: :button, class: nil, data: {}, **options, &block)
```

- Icon-only button, required `label:` for accessibility.

### `page_header`

```ruby
page_header(title:, subtitle: nil, actions: nil, &block)
```

- Standard page header shell for title/subtitle/actions.

### `empty_state`

```ruby
empty_state(title:, body: nil, icon: nil, actions: nil, &block)
```

- Standardized empty-state card.

### `danger_zone`

```ruby
danger_zone(title:, description:, actions: nil, &block)
```

- Standardized destructive action container.

### `back_link`

```ruby
back_link(text, path, **options)
```

- Canonical compact back link.

### `modal`

```ruby
modal(id:, title:, frame: nil, &block)
```

- Renders a native `<dialog>` modal with title, close button, and content.
- **Inline mode** (default): Content is rendered on the page inside the dialog.
- **Lazy mode** (`frame:`): Wraps content in a `<turbo-frame>` that auto-opens the dialog when the frame navigates.

```erb
<%# Inline modal %>
<%= modal(id: dom_id(@app, :domain_modal), title: "Add Domain") do %>
  <%= render "form", domain: @app.domains.new %>
<% end %>

<%# Lazy modal (loaded via turbo frame) %>
<%= modal(id: "env_var_modal", title: "Add Variable", frame: "env_variable_form") do %>
  <%= render "form", env_variable: @app.env_variables.new %>
<% end %>
```

### `modal_frame`

```ruby
modal_frame(frame_id, title:, &block)
```

- Used in `new`/`edit` views that load into a lazy modal's turbo frame.
- Wraps content in a `<turbo-frame>` with the modal header (title + close button).

```erb
<%# app/views/things/new.html.erb %>
<%= modal_frame "thing_form", title: "Add Thing" do %>
  <%= render "form", thing: @thing %>
<% end %>
```

### `modal_trigger`

```ruby
modal_trigger(text = nil, modal_id:, variant: :primary, size: :sm, **options, &block)
```

- Canonical modal trigger using Stimulus (`dialog-trigger`).

## Shared UI Partials

- `app/views/shared/ui/_page_header.html.erb`
- `app/views/shared/ui/_empty_state.html.erb`
- `app/views/shared/ui/_danger_zone.html.erb`

## Shared Controls

- `app/views/shared/_modal.html.erb`
- `app/views/shared/_modal_frame.html.erb`
- `app/views/shared/_pagination.html.erb`
- `app/views/shared/_toast.html.erb`

These controls should use semantic UI helpers (`button` / `icon_button`) instead of raw ad hoc bundles.

## Accessibility Defaults

- All icon-only actions must use `icon_button(label: ...)`.
- All raw `<button>` tags must include explicit `type`.
- Toasts must keep dismiss controls keyboard accessible.
- Back links and modal triggers should remain semantically links/buttons (not non-interactive elements with click handlers).
