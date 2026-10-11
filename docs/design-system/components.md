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
submit_button(text, variant: :primary, size: :sm, **options)
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

### Rendered verification

Rails helper/integration tests: `PARALLEL_WORKERS=1
POSTGRES_TEST_DB=<isolated_test_database> mise exec -- bin/rails test`.
Clipboard controller regression: `mise exec -- node --test
 test/javascript/clipboard_controller_test.mjs`.

The standalone Playwright system harness requires a real Rails test server,
nonsecret seeded rows and an isolated signed test-session JSON (`cookie`,
`base`, the project's app URL). Never use a production session/database.
Install Python Playwright in a scratch venv, then run:

```sh
python test/system/settings_browser_test.py \
  --state /scratch/browser-state.json --output /scratch/screenshots \
  --origin http://127.0.0.1:3138 --chromium /path/to/chrome
```

It verifies 1280/390/320px geometry, true expanded pointer hits, nonoverlap,
keyboard/focus/outside-click behavior, native modal Cancel, independent
General saves and overflow, and captures the rendered Rails screens.
After CSS-only edits force a test build with `RAILS_ENV=test bin/vite build
--mode test --force`: Vite's default watched paths may otherwise skip the
external application stylesheet. Restart test Rails after Ruby/template
edits because test-environment reloading is disabled.
