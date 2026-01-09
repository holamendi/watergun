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
│  Logo    Projects ▼    Activity    [Search]           Settings  │  <- Top bar
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│                        Main Content                             │
│                                                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

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

### Phase 1: Foundation (Complete)
- [x] Analysis complete
- [x] Create new layout structure (top nav replaces sidebar)
- [x] Top navigation component
- [x] Project index (dashboard) with cards
- [x] Project detail with app/service rows
- [x] App detail page with tabs and process cards
- [x] Service detail page with tabs
- [x] Tests updated

### Phase 2: Project Management
- [ ] Projects index (dashboard grid)
- [ ] Project show (resources list)
- [ ] Project new/edit forms

### Phase 3: App Management
- [ ] App detail page with tabs
- [ ] Deployments list
- [ ] App creation form
- [ ] Quick actions (deploy, restart)

### Phase 4: Service Management
- [ ] Service detail page
- [ ] Service creation form
- [ ] Service linking UI

### Phase 5: Supporting Pages
- [ ] Environment variables editor
- [ ] Domains management
- [ ] Logs viewer
- [ ] Metrics display

### Phase 6: Settings & Polish
- [ ] Account settings
- [ ] Theme refinement
- [ ] Mobile responsiveness
- [ ] Empty states

---

## Component Library (Helpers/Partials)

### Helpers (app/helpers/ui_helper.rb)
- `page_header(title, &actions)` - existing, keep
- `status_dot(status)` - existing, keep
- `status_badge(status)` - existing, keep
- `quick_action_button(text, path, icon:, variant:)` - NEW
- `stat_card(label, value, icon:)` - NEW
- `empty_state(title, description, &action)` - NEW

### Partials (app/views/shared/)
- `_top_nav.html.erb` - NEW
- `_resource_card.html.erb` - NEW
- `_action_dropdown.html.erb` - existing as dropdown
- `_tabs.html.erb` - NEW
- `_form_section.html.erb` - NEW

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

---

## Notes

- Keep existing Turbo Stream patterns for real-time updates
- Preserve ServerAction broadcasting for live status
- Icon system: continue using inline Heroicons (simple, no dependencies)
- Forms: use Rails form helpers with DaisyUI classes
