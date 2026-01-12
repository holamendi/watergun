# Watergun UI Redesign Plan

## Overview

Full UI rethink with devtools aesthetic. Simple, quick actions prominent, advanced features behind clicks.

**Constraints:**
- Vanilla Rails (partials + helpers, no ViewComponent)
- DaisyUI 5 + Tailwind CSS 4
- Small scale: dozens of items, not hundreds
- Iterative development with commits between sections

---

## Design Principles

1. **Quick actions first** - Deploy, restart, view logs should be 1-click
2. **Progressive disclosure** - Basic info visible, details on demand
3. **Devtools aesthetic** - Dark theme, monospace where appropriate, terminal-like feel
4. **Minimal chrome** - Let content breathe, reduce visual noise
5. **Context-aware** - Show relevant actions based on current state

---

## Architecture

### Layout Structure

```
┌─────────────────────────────────────────────────────────────────┐
│  Logo    [Project ▼]    Activity                      ⚙  👤  ≡  │  <- Top bar
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│                        Main Content                             │
│                                                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

Note: Search (Cmd+K) deferred to Phase 4.

**Key change:** Replace two-level sidebar with simpler top navigation.
- Cleaner, more horizontal space for content
- Dropdown for project switching
- Mobile: hamburger menu

### Page Hierarchy

```
/projects                    <- Dashboard: all projects grid
/projects/new                <- Create project form
/projects/:id                <- Project detail: apps + services list
/projects/:id/apps/new       <- Create app form
/projects/:id/apps/:id       <- App detail (tabs: deploys, logs, config)
/projects/:id/services/new   <- Create service form
/projects/:id/services/:id   <- Service detail
/server_actions              <- Activity log
/account                     <- Settings
```

---

## Implementation Phases

### Phase 1: Foundation & Core Pages (Complete)
- [x] Analysis complete
- [x] Create new layout structure (top nav replaces sidebar)
- [x] Top navigation with project selector dropdown
- [x] Project index (dashboard) with cards grid
- [x] Project detail with app/service rows + quick actions
- [x] App detail page with tabs, process cards, linked services
- [x] Service detail page with tabs, linked apps
- [x] Removed old sidebar files (icon rail, context panel, mobile nav)
- [x] Tests updated for new UI structure
- [x] Moved queries from views to controllers (eager loading)

### Phase 2: Forms (Complete)
- [x] Project new/edit forms
- [x] App new/edit forms (including create form, settings sections)
- [x] Service new/edit forms (including create form)

### Phase 3: Supporting Pages (Complete)
- [x] Environment variables editor (redesigned with card layout, icon buttons)
- [x] Domains management (card-based list with status badges, dropdown actions)
- [x] Logs viewer improvements (added header with tabs, terminal-style display)
- [x] Metrics display improvements (card-based stats, consistent chart styling)
- [x] Created shared header partials for apps and services (consistent tabs navigation)
- [x] All tab pages now include full app/service context with actions

### Phase 4: Settings & Polish (Complete)
- [x] Account settings page (card-based sections, consistent styling)
- [x] Mobile responsiveness audit (tabs overflow, header stacking)
- [x] Empty states (activity page, consistency check)
- [ ] Cmd+K search feature (deferred to future phase)

---

## Component Library (Helpers/Partials)

### Helpers (app/helpers/ui_helper.rb)
- `page_header(title, &actions)` - existing
- `status_dot(status)` - existing
- `status_badge(status)` - existing

### Partials Created
- `app/views/layouts/_top_nav.html.erb` - Top navigation with project dropdown
- `app/views/projects/_project.html.erb` - Project card for dashboard
- `app/views/projects/apps/_app_row.html.erb` - App row with quick actions
- `app/views/projects/apps/_header.html.erb` - App header with tabs navigation
- `app/views/projects/services/_service_row.html.erb` - Service row
- `app/views/projects/services/_header.html.erb` - Service header with tabs navigation
- `app/views/projects/apps/deployments/_deployment_row.html.erb` - Deployment row

### Partials Removed
- `app/views/layouts/_sidebar.html.erb`
- `app/views/layouts/_icon_rail.html.erb`
- `app/views/layouts/_context_panel.html.erb`
- `app/views/layouts/_mobile_nav.html.erb`

---

## Data Model Reference

```
Project
├── App (e.g., "my-rails-app")
│   ├── Process/Container: web.1      ← from Procfile
│   ├── Process/Container: worker.1
│   └── Process/Container: clock.1
└── Service (e.g., postgres)
    └── Container
```

**Key insight:** An App is a single deployable unit that may spawn multiple process types.
"web" and "worker" are processes within one app, not separate apps.

---

## UI Decisions

- **Server info:** Hide by default. Show only when account has multiple servers.
- **Process info:** Show process status inline with app (e.g., `web ● worker ● clock ●`)
- **Quick actions:** Inline with each resource row (Deploy, Logs, overflow menu)

---

## ASCII Mockups

### Dashboard (Projects Index)

```
┌─────────────────────────────────────────────────────────────────────────┐
│  🔫 Watergun     Projects      Activity                      ⚙ Settings │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   Projects                                        [+ New Project]       │
│                                                                         │
│   ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────┐ │
│   │ my-saas-app         │  │ blog                │  │ api-service     │ │
│   │ ● 2 apps  ○ 1 svc   │  │ ● 1 app   ○ 1 svc   │  │ ● 3 apps        │ │
│   │                     │  │                     │  │                 │ │
│   │ Last deploy: 2h ago │  │ Last deploy: 1d ago │  │ Last: 5m ago    │ │
│   └─────────────────────┘  └─────────────────────┘  └─────────────────┘ │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Project Detail

```
┌─────────────────────────────────────────────────────────────────────────┐
│  my-saas-app                                       [+ App] [+ Service]  │
│  ← Projects                                                         ⚙   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  APPS                                                                   │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  ● rails-app       main · 2h ago        [Deploy] [Logs]     ⋮     │  │
│  │    web ●  worker ●  clock ●                                       │  │
│  ├───────────────────────────────────────────────────────────────────┤  │
│  │  ● marketing-site  main · 1d ago        [Deploy] [Logs]     ⋮     │  │
│  │    web ●                                                          │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  SERVICES                                                               │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  ○ postgres        PostgreSQL 15        [Logs]              ⋮     │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘

● = running    ○ = stopped/error
⋮ = overflow menu (Settings, Domains, Variables, Delete...)
```

### App Detail (with process metrics)

```
┌─────────────────────────────────────────────────────────────────────────┐
│  ← my-saas-app                                                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  rails-app                                         [Deploy] [Restart]   │
│  main branch · deployed 2h ago                                      ⚙   │
│                                                                         │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                        │
│  │ web ●       │ │ worker ●    │ │ clock ●     │    <- process cards    │
│  │ 45% CPU     │ │ 12% CPU     │ │ 2% CPU      │                        │
│  │ 512MB       │ │ 256MB       │ │ 128MB       │                        │
│  └─────────────┘ └─────────────┘ └─────────────┘                        │
│                                                                         │
│  [Deployments]  [Logs]  [Variables]  [Domains]                          │
│  ────────────────────────────────────────────                           │
│                                                                         │
│  │ ● ab2c3d  Fix login bug       2h ago   user@example.com              │
│  │ ● c4d5e6f Add feature         1d ago   user@example.com              │
│  │ ○ f7g8h9i Deploy failed       2d ago   user@example.com              │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Create Project Form

```
┌─────────────────────────────────────────────────────────────────────────┐
│  🔫 Watergun     Projects ▼     Activity                     ⚙ Settings │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ← Projects    New Project                                             │
│                                                                         │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                                                                 │   │
│   │   Project Name                                                  │   │
│   │   ┌───────────────────────────────────────────────────────────┐ │   │
│   │   │ my-new-project                                            │ │   │
│   │   └───────────────────────────────────────────────────────────┘ │   │
│   │   A short identifier for your project                           │   │
│   │                                                                 │   │
│   │   Server  (only shown if multiple servers)                      │   │
│   │   ┌───────────────────────────────────────────────────────────┐ │   │
│   │   │ server-1                                              ▼   │ │   │
│   │   └───────────────────────────────────────────────────────────┘ │   │
│   │                                                                 │   │
│   │                                      [Cancel]  [Create Project] │   │
│   │                                                                 │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Session Log

### Session 1
- Completed codebase analysis
- Created this plan document
- Implemented Phase 1: Foundation
  - New application layout with top navigation
  - Removed sidebar (icon rail, context panel, mobile nav)
  - Updated projects index with card grid
  - Updated project show with app/service rows + quick actions
  - Created app show page with tabs, process cards, linked services
  - Created service show page with tabs, linked apps
  - Updated tests for new UI structure
  - All tests passing (159 tests, 0 failures)
- Commit: `7ea55c7` - UI Redesign Phase 1

### Session 2
- Fixed navbar layout (items were wrapping to second row)
- Added project selector dropdown to top nav
- Removed "New Project" link from dropdown (deferred)
- Moved queries from views to controllers:
  - Added `@nav_projects` in ApplicationController
  - Eager loading in ProjectsController (apps, services, containers, linked_apps)
  - Added `@linked_services` and `@linked_apps` instance variables
  - Updated views to use in-memory filtering (`.select(&:kept?)`, `.select(&:running?)`)
- Moved work to `ui-redesign` branch
- All tests passing (159 tests, 0 failures)
- Commit: `0fa4919` - Add project selector dropdown and move queries to controllers
- Implemented Phase 2: Forms
  - Updated project new/edit pages with consistent layout
  - Updated app new/edit pages (create form, settings with sections)
  - Updated service new/edit pages (create form, settings)
  - All forms now use consistent back links, card styling, fieldset patterns
- All tests passing (159 tests, 0 failures)

### Session 3
- Implemented Phase 3: Supporting Pages
  - Created shared header partials for apps (`_header.html.erb`) and services
  - Header partials include: back link, title, status, metadata, actions, tabs
  - Updated environment variables page with card layout, icon action buttons
  - Updated domains page with card-based list, status badges, SSL indicator
  - Updated logs viewer with header context, terminal-style display
  - Updated metrics pages with card-based stats, consistent chart styling
  - Updated deployments index with header and empty state
  - All tab pages now have consistent navigation and app/service context
- All tests passing (159 tests, 0 failures)

### Session 4
- Implemented Phase 4: Settings & Polish
  - Updated account settings page with card-based sections
  - Updated activity page with consistent styling and empty state
  - Added mobile responsiveness improvements:
    - Tabs now have `overflow-x-auto` for horizontal scroll on mobile
    - Headers stack vertically on small screens (`flex-col sm:flex-row`)
  - Cmd+K search feature deferred to future phase
- All tests passing (159 tests, 0 failures)

---

## Notes

- Keep existing Turbo Stream patterns for real-time updates
- Preserve ServerAction broadcasting for live status
- Icon system: continue using inline Heroicons (simple, no dependencies)
- Forms: use Rails form helpers with DaisyUI classes
