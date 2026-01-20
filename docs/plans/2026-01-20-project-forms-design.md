# Project Forms Redesign

Redesign the new and edit project forms to match the design system.

## Overview

Both forms use a centered card layout at max-w-sm (~384px). The new form is a simple single-field form. The edit form uses the inline save pattern with a danger zone section.

## New Project Form

**Layout:** Centered card with back link

**Fields:**
- Name (text input with helper text)

**Actions:**
- Cancel (ghost button, links to projects index)
- Create Project (primary button)

**Notes:**
- No server selector - server assigned by controller
- Back link: chevron + "Projects"

```
┌─────────────────────────────────────────┐
│  ‹ Projects                             │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  New Project                      │  │
│  │                                   │  │
│  │  Name                             │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │ my-project                  │  │  │
│  │  └─────────────────────────────┘  │  │
│  │  A short identifier for your...   │  │
│  │                                   │  │
│  │           Cancel  [Create Project]│  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## Edit Project Form (Settings)

**Layout:** Centered card with back link

**Sections:**
1. General - project name with inline save
2. Danger zone - delete project

**Notes:**
- Back link: chevron + project name
- Title: "Settings"
- Inline save pattern (field + save button in row)
- Danger zone separated by border-top

```
┌─────────────────────────────────────────┐
│  ‹ my-project                           │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  Settings                         │  │
│  │                                   │  │
│  │  Project name                     │  │
│  │  ┌─────────────────────┐ ┌──────┐│  │
│  │  │ my-project          │ │ Save ││  │
│  │  └─────────────────────┘ └──────┘│  │
│  │                                   │  │
│  │  ─────────────────────────────── │  │
│  │                                   │  │
│  │  Danger zone                      │  │
│  │  Deleting this project will...    │  │
│  │                                   │  │
│  │  [ Delete project ]               │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## Files to Change

1. `app/views/projects/_form.html.erb` - simplify to just name field
2. `app/views/projects/new.html.erb` - update back link to chevron pattern
3. `app/views/projects/edit.html.erb` - full rewrite with settings layout and danger zone

## Design Tokens Used

- Back link: chevron + context (new pattern)
- Form layout: centered card at max-w-sm
- Inline save: field + button in flex row
- Danger zone: border-t separator, red heading, outline button
