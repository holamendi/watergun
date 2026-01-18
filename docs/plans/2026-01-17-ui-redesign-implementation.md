# UI Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace DaisyUI with vanilla Tailwind using the "Hybrid Dense" design system - dark theme, vibrant accents, dense layouts.

**Architecture:** Update Tailwind config with custom theme, then migrate pages one-by-one starting with layout/nav, then projects index, project show, app show. Extract reusable patterns into helpers/partials as we go.

**Tech Stack:** Tailwind CSS 4, vanilla (no DaisyUI), Inter + JetBrains Mono fonts

**Design Reference:** `docs/plans/2026-01-17-ui-redesign-design.md`

**Preview File:** `tmp/ui-preview-hybrid.html`

---

## Task 1: Update Tailwind Configuration

**Files:**
- Modify: `config/tailwind.config.js`
- Modify: `app/views/layouts/application.html.erb` (font imports)
- Modify: `package.json` (remove daisyui if present)

**Step 1: Check current Tailwind config**

Run: `cat config/tailwind.config.js`

Note what's there before modifying.

**Step 2: Update Tailwind config with new theme**

Replace `config/tailwind.config.js` with:

```javascript
const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}'
  ],
  theme: {
    extend: {
      colors: {
        base: '#121218',
        surface: '#1a1a22',
        elevated: '#24242e',
        border: '#2e2e3a',
        'border-strong': '#3e3e4a',
        'text-primary': '#f0f0f5',
        'text-secondary': '#9898a8',
        'text-muted': '#606070',
        accent: '#6c5ce7',
        'accent-hover': '#8577ed',
        success: '#00cec9',
        'success-soft': 'rgba(0, 206, 201, 0.125)',
        warning: '#fdcb6e',
        'warning-soft': 'rgba(253, 203, 110, 0.125)',
        error: '#ff7675',
        'error-soft': 'rgba(255, 118, 117, 0.125)',
        pink: '#fd79a8',
      },
      fontFamily: {
        sans: ['Inter', ...defaultTheme.fontFamily.sans],
        mono: ['JetBrains Mono', ...defaultTheme.fontFamily.mono],
      },
      fontSize: {
        'xxs': ['0.65rem', { lineHeight: '1rem' }],
      },
      borderRadius: {
        DEFAULT: '6px',
        'lg': '8px',
        'xl': '10px',
      },
    },
  },
  plugins: [],
}
```

**Step 3: Add Google Fonts to layout**

In `app/views/layouts/application.html.erb`, add in `<head>` before other stylesheets:

```erb
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
```

**Step 4: Remove DaisyUI from package.json if present**

Run: `grep daisyui package.json` - if found, remove it with `npm uninstall daisyui`

**Step 5: Rebuild assets and verify**

Run: `bin/vite build`
Expected: Build completes without errors

**Step 6: Run tests**

Run: `bin/rails test`
Expected: All tests pass (CSS changes shouldn't break tests)

**Step 7: Commit**

```bash
git add config/tailwind.config.js app/views/layouts/application.html.erb package.json
git commit -m "Configure Tailwind with Hybrid Dense theme

- Add custom color palette (base, surface, elevated, accents)
- Configure Inter and JetBrains Mono fonts
- Set border radius defaults (6px, 8px, 10px)
- Remove DaisyUI dependency"
```

---

## Task 2: Update Application Layout

**Files:**
- Modify: `app/views/layouts/application.html.erb`
- Modify: `app/assets/stylesheets/application.tailwind.css`

**Step 1: Read current layout**

Run: `cat app/views/layouts/application.html.erb`

**Step 2: Update base styles in application.tailwind.css**

Add at the top of `app/assets/stylesheets/application.tailwind.css`:

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  body {
    @apply bg-base text-text-primary;
    font-family: 'Inter', system-ui, sans-serif;
    font-size: 13px;
  }
}

@layer components {
  .glass {
    background: rgba(26, 26, 34, 0.8);
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
  }
}
```

**Step 3: Update layout body classes**

In `application.html.erb`, update the `<body>` tag:

```erb
<body class="bg-base text-text-primary min-h-screen">
```

**Step 4: Verify in browser**

Run: `bin/dev`
Visit: http://localhost:3000
Expected: Dark background (#121218), light text

**Step 5: Commit**

```bash
git add app/views/layouts/application.html.erb app/assets/stylesheets/application.tailwind.css
git commit -m "Apply base dark theme to layout"
```

---

## Task 3: Update Top Navigation

**Files:**
- Modify: `app/views/layouts/_top_nav.html.erb`

**Step 1: Read current nav partial**

Run: `cat app/views/layouts/_top_nav.html.erb`

**Step 2: Rewrite nav with new design**

Replace `app/views/layouts/_top_nav.html.erb` with:

```erb
<nav class="glass border-b border-border sticky top-0 z-50">
  <div class="max-w-7xl mx-auto px-4">
    <div class="flex items-center justify-between h-12">
      <div class="flex items-center gap-5">
        <%= link_to root_path, class: "font-semibold text-base bg-gradient-to-r from-accent to-pink bg-clip-text text-transparent" do %>
          Watergun
        <% end %>

        <div class="flex items-center gap-0.5">
          <%= link_to "Projects", projects_path,
              class: "px-3 py-1.5 text-xs rounded-lg #{current_page?(projects_path) ? 'text-text-primary bg-elevated font-medium' : 'text-text-secondary hover:text-text-primary'}" %>
          <%= link_to "Activity", server_actions_path,
              class: "px-3 py-1.5 text-xs rounded-lg #{current_page?(server_actions_path) ? 'text-text-primary bg-elevated font-medium' : 'text-text-secondary hover:text-text-primary'}" %>
          <%= link_to "Settings", account_path,
              class: "px-3 py-1.5 text-xs rounded-lg #{current_page?(account_path) ? 'text-text-primary bg-elevated font-medium' : 'text-text-secondary hover:text-text-primary'}" %>
        </div>
      </div>

      <div class="flex items-center gap-2">
        <span class="text-xs text-text-muted"><%= Current.user&.email %></span>
        <div class="w-6 h-6 rounded-full bg-gradient-to-br from-accent to-pink"></div>
      </div>
    </div>
  </div>
</nav>
```

**Step 3: Verify in browser**

Visit: http://localhost:3000
Expected: Glass-effect navbar with gradient logo, proper active states

**Step 4: Run tests**

Run: `bin/rails test`
Expected: All tests pass

**Step 5: Commit**

```bash
git add app/views/layouts/_top_nav.html.erb
git commit -m "Update nav with glass effect and gradient logo"
```

---

## Task 4: Update UI Helper for Status Indicators

**Files:**
- Modify: `app/helpers/ui_helper.rb`

**Step 1: Read current helper**

Run: `cat app/helpers/ui_helper.rb`

**Step 2: Update status_dot helper**

Add or update in `app/helpers/ui_helper.rb`:

```ruby
def status_dot(status, size: 2)
  color_class = case status.to_s
  when "running", "active", "success", "completed"
    "bg-success shadow-success/50"
  when "deploying", "pending", "warning"
    "bg-warning shadow-warning/50 animate-pulse"
  when "failed", "error"
    "bg-error shadow-error/50"
  else
    "bg-text-muted"
  end

  tag.span(class: "w-#{size} h-#{size} rounded-full #{color_class} shadow inline-block")
end

def status_badge(status)
  colors = case status.to_s
  when "running", "active", "success", "completed"
    "bg-success-soft text-success"
  when "deploying", "pending", "warning"
    "bg-warning-soft text-warning"
  when "failed", "error"
    "bg-error-soft text-error"
  else
    "bg-elevated text-text-muted"
  end

  tag.span(status.to_s.titleize, class: "px-2 py-0.5 text-xxs font-medium rounded #{colors}")
end
```

**Step 3: Run tests**

Run: `bin/rails test`
Expected: All tests pass

**Step 4: Commit**

```bash
git add app/helpers/ui_helper.rb
git commit -m "Update status helpers with new color scheme"
```

---

## Task 5: Update Projects Index (Dashboard)

**Files:**
- Modify: `app/views/projects/index.html.erb`
- Modify: `app/views/projects/_project.html.erb`

**Step 1: Read current views**

```bash
cat app/views/projects/index.html.erb
cat app/views/projects/_project.html.erb
```

**Step 2: Update projects index**

Replace `app/views/projects/index.html.erb`:

```erb
<div class="max-w-6xl mx-auto px-4 py-6">
  <div class="flex items-center justify-between mb-6">
    <h1 class="text-xl font-semibold">Projects</h1>
    <%= link_to new_project_path, class: "px-4 py-2 bg-gradient-to-r from-accent to-accent-hover text-white text-xs font-medium rounded-lg shadow shadow-accent/20 hover:opacity-90 transition-all" do %>
      New Project
    <% end %>
  </div>

  <% if @projects.any? %>
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
      <%= render @projects %>
    </div>
  <% else %>
    <div class="bg-surface rounded-xl border border-border p-12 text-center">
      <p class="text-text-secondary mb-4">No projects yet</p>
      <%= link_to "Create your first project", new_project_path, class: "text-accent hover:underline" %>
    </div>
  <% end %>
</div>
```

**Step 3: Update project card partial**

Replace `app/views/projects/_project.html.erb`:

```erb
<%= link_to project_path(project),
    class: "group bg-surface rounded-xl border border-border p-4 hover:border-accent/50 hover:shadow-lg hover:shadow-accent/10 transition-all" do %>
  <div class="flex items-center justify-between mb-2">
    <div class="flex items-center gap-2">
      <div class="w-8 h-8 rounded-lg bg-gradient-to-br from-accent to-pink flex items-center justify-center text-white text-xs font-bold">
        <%= project.name.first.upcase %>
      </div>
      <span class="font-medium group-hover:text-accent transition-colors"><%= project.name %></span>
    </div>
    <%= status_dot(project.status) %>
  </div>

  <div class="flex items-center gap-3 text-xs text-text-secondary mb-2">
    <span><%= project.apps.kept.count %> apps</span>
    <span><%= project.services.kept.count %> services</span>
  </div>

  <% if project.apps.kept.any? %>
    <div class="text-xxs text-text-muted">
      Last deploy <%= time_ago_in_words(project.apps.kept.map(&:last_deployed_at).compact.max || project.created_at) %> ago
    </div>
  <% end %>
<% end %>
```

**Step 4: Verify in browser**

Visit: http://localhost:3000/projects
Expected: Dark cards with gradient icons, hover effects

**Step 5: Run tests**

Run: `bin/rails test test/controllers/projects_controller_test.rb`
Expected: All tests pass

**Step 6: Commit**

```bash
git add app/views/projects/index.html.erb app/views/projects/_project.html.erb
git commit -m "Update projects index with card grid layout"
```

---

## Task 6: Update Project Show Page

**Files:**
- Modify: `app/views/projects/show.html.erb`
- Modify: `app/views/projects/apps/_app_row.html.erb`
- Modify: `app/views/projects/services/_service_row.html.erb`

**Step 1: Read current views**

```bash
cat app/views/projects/show.html.erb
cat app/views/projects/apps/_app_row.html.erb
cat app/views/projects/services/_service_row.html.erb
```

**Step 2: Update project show page**

Replace `app/views/projects/show.html.erb`:

```erb
<div class="max-w-6xl mx-auto px-4 py-6">
  <!-- Header -->
  <div class="flex items-center justify-between mb-6">
    <div>
      <%= link_to projects_path, class: "text-xs text-text-muted hover:text-text-secondary mb-1 inline-block" do %>
        &larr; Projects
      <% end %>
      <h1 class="text-xl font-semibold flex items-center gap-2">
        <%= @project.name %>
        <%= status_dot(@project.status) %>
      </h1>
    </div>
    <div class="flex items-center gap-2">
      <%= link_to new_project_app_path(@project), class: "px-4 py-2 bg-gradient-to-r from-accent to-accent-hover text-white text-xs font-medium rounded-lg shadow shadow-accent/20" do %>
        New App
      <% end %>
      <%= link_to new_project_service_path(@project), class: "px-4 py-2 bg-elevated hover:bg-border text-text-primary text-xs font-medium rounded-lg border border-border" do %>
        New Service
      <% end %>
    </div>
  </div>

  <!-- Apps Section -->
  <div class="mb-6">
    <h2 class="text-xs font-medium text-text-muted uppercase tracking-wider mb-3">Apps (<%= @project.apps.kept.count %>)</h2>
    <% if @project.apps.kept.any? %>
      <div class="bg-surface rounded-xl border border-border divide-y divide-border">
        <%= render @project.apps.kept %>
      </div>
    <% else %>
      <div class="bg-surface rounded-xl border border-border p-6 text-center">
        <p class="text-text-secondary text-sm">No apps yet</p>
      </div>
    <% end %>
  </div>

  <!-- Services Section -->
  <div>
    <h2 class="text-xs font-medium text-text-muted uppercase tracking-wider mb-3">Services (<%= @project.services.kept.count %>)</h2>
    <% if @project.services.kept.any? %>
      <div class="bg-surface rounded-xl border border-border divide-y divide-border">
        <%= render @project.services.kept %>
      </div>
    <% else %>
      <div class="bg-surface rounded-xl border border-border p-6 text-center">
        <p class="text-text-secondary text-sm">No services yet</p>
      </div>
    <% end %>
  </div>
</div>
```

**Step 3: Update app row partial**

Replace `app/views/projects/apps/_app_row.html.erb`:

```erb
<div class="px-4 py-3 hover:bg-elevated/30 transition-colors" id="<%= dom_id(app) %>">
  <div class="flex items-center justify-between">
    <div class="flex items-center gap-3">
      <div class="w-9 h-9 rounded-lg bg-gradient-to-br from-accent to-pink flex items-center justify-center">
        <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>
        </svg>
      </div>
      <div>
        <%= link_to app.name, project_app_overview_path(app.project, app), class: "font-mono text-sm font-medium hover:text-accent transition-colors" %>
        <div class="flex items-center gap-2 mt-0.5 text-xxs text-text-muted">
          <span class="px-1.5 py-0.5 bg-elevated rounded"><%= app.branch || "main" %></span>
          <% if app.last_deployed_at %>
            <span><%= time_ago_in_words(app.last_deployed_at) %> ago</span>
          <% end %>
          <% app.containers.running.group_by(&:process_type).each do |type, _| %>
            <span class="text-success">● <%= type %></span>
          <% end %>
        </div>
      </div>
    </div>

    <div class="flex items-center gap-2">
      <%= button_to "Deploy", project_app_deployments_path(app.project, app),
          method: :post,
          class: "px-3 py-1.5 bg-accent hover:bg-accent-hover text-white rounded-lg text-xs font-medium shadow shadow-accent/20" %>
      <%= link_to "Logs", project_app_logs_path(app.project, app),
          class: "px-3 py-1.5 text-text-secondary hover:text-text-primary hover:bg-elevated rounded-lg text-xs" %>
      <div class="relative" data-controller="dropdown">
        <button data-action="click->dropdown#toggle" class="p-1.5 text-text-muted hover:text-text-primary hover:bg-elevated rounded-lg">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 5v.01M12 12v.01M12 19v.01"/>
          </svg>
        </button>
      </div>
    </div>
  </div>
</div>
```

**Step 4: Update service row partial**

Replace `app/views/projects/services/_service_row.html.erb`:

```erb
<div class="px-4 py-3 hover:bg-elevated/30 transition-colors" id="<%= dom_id(service) %>">
  <div class="flex items-center justify-between">
    <div class="flex items-center gap-3">
      <%= status_dot(service.status) %>
      <div>
        <%= link_to service.name, project_service_overview_path(service.project, service), class: "font-mono text-sm font-medium hover:text-accent transition-colors" %>
        <p class="text-xxs text-text-muted mt-0.5"><%= service.service_type.titleize %></p>
      </div>
    </div>

    <div class="flex items-center gap-2">
      <%= link_to "Logs", project_service_logs_path(service.project, service),
          class: "px-3 py-1.5 text-text-secondary hover:text-text-primary hover:bg-elevated rounded-lg text-xs" %>
      <div class="relative" data-controller="dropdown">
        <button data-action="click->dropdown#toggle" class="p-1.5 text-text-muted hover:text-text-primary hover:bg-elevated rounded-lg">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 5v.01M12 12v.01M12 19v.01"/>
          </svg>
        </button>
      </div>
    </div>
  </div>
</div>
```

**Step 5: Verify in browser**

Visit: http://localhost:3000/projects/:id
Expected: Clean layout with app/service rows, gradient icons, proper actions

**Step 6: Run tests**

Run: `bin/rails test test/controllers/projects_controller_test.rb`
Expected: All tests pass

**Step 7: Commit**

```bash
git add app/views/projects/show.html.erb app/views/projects/apps/_app_row.html.erb app/views/projects/services/_service_row.html.erb
git commit -m "Update project show with dense app/service rows"
```

---

## Task 7: Update App Header and Tabs

**Files:**
- Modify: `app/views/projects/apps/_header.html.erb`

**Step 1: Read current header**

Run: `cat app/views/projects/apps/_header.html.erb`

**Step 2: Update app header with segmented tabs**

Replace `app/views/projects/apps/_header.html.erb`:

```erb
<div class="bg-surface border-b border-border">
  <div class="max-w-6xl mx-auto px-4 py-4">
    <!-- Back + Title -->
    <div class="flex items-center justify-between mb-4">
      <div>
        <%= link_to project_path(@app.project), class: "text-xs text-text-muted hover:text-text-secondary mb-1 inline-block" do %>
          &larr; <%= @app.project.name %>
        <% end %>
        <h1 class="text-xl font-semibold flex items-center gap-2">
          <span class="font-mono"><%= @app.name %></span>
          <%= status_dot(@app.status) %>
        </h1>
        <div class="text-xs text-text-muted mt-1">
          <% if @app.last_deployed_at %>
            Last deployed <%= time_ago_in_words(@app.last_deployed_at) %> ago
          <% else %>
            Never deployed
          <% end %>
        </div>
      </div>

      <div class="flex items-center gap-2">
        <%= button_to "Deploy", project_app_deployments_path(@app.project, @app),
            method: :post,
            class: "px-4 py-2 bg-gradient-to-r from-accent to-accent-hover text-white text-xs font-medium rounded-lg shadow shadow-accent/20" %>
        <%= button_to "Restart", project_app_restart_path(@app.project, @app),
            method: :post,
            class: "px-4 py-2 bg-elevated hover:bg-border text-text-primary text-xs font-medium rounded-lg border border-border" %>
      </div>
    </div>

    <!-- Tabs -->
    <div class="inline-flex bg-elevated rounded-lg p-0.5">
      <%= link_to "Overview", project_app_overview_path(@app.project, @app),
          class: "px-3 py-1.5 text-xs rounded-md #{current_page?(project_app_overview_path(@app.project, @app)) ? 'text-text-primary bg-surface shadow-sm font-medium' : 'text-text-secondary hover:text-text-primary'}" %>
      <%= link_to "Deployments", project_app_deployments_path(@app.project, @app),
          class: "px-3 py-1.5 text-xs rounded-md #{request.path.include?('deployments') ? 'text-text-primary bg-surface shadow-sm font-medium' : 'text-text-secondary hover:text-text-primary'}" %>
      <%= link_to "Logs", project_app_logs_path(@app.project, @app),
          class: "px-3 py-1.5 text-xs rounded-md #{current_page?(project_app_logs_path(@app.project, @app)) ? 'text-text-primary bg-surface shadow-sm font-medium' : 'text-text-secondary hover:text-text-primary'}" %>
      <%= link_to "Variables", project_app_config_vars_path(@app.project, @app),
          class: "px-3 py-1.5 text-xs rounded-md #{current_page?(project_app_config_vars_path(@app.project, @app)) ? 'text-text-primary bg-surface shadow-sm font-medium' : 'text-text-secondary hover:text-text-primary'}" %>
      <%= link_to "Domains", project_app_domains_path(@app.project, @app),
          class: "px-3 py-1.5 text-xs rounded-md #{current_page?(project_app_domains_path(@app.project, @app)) ? 'text-text-primary bg-surface shadow-sm font-medium' : 'text-text-secondary hover:text-text-primary'}" %>
      <%= link_to "Settings", edit_project_app_path(@app.project, @app),
          class: "px-3 py-1.5 text-xs rounded-md #{current_page?(edit_project_app_path(@app.project, @app)) ? 'text-text-primary bg-surface shadow-sm font-medium' : 'text-text-secondary hover:text-text-primary'}" %>
    </div>
  </div>
</div>
```

**Step 3: Verify in browser**

Visit: http://localhost:3000/projects/:id/apps/:id
Expected: App header with segmented control tabs, gradient deploy button

**Step 4: Run tests**

Run: `bin/rails test test/controllers/projects/apps_controller_test.rb`
Expected: All tests pass

**Step 5: Commit**

```bash
git add app/views/projects/apps/_header.html.erb
git commit -m "Update app header with segmented control tabs"
```

---

## Task 8: Update Forms (Project New/Edit)

**Files:**
- Modify: `app/views/projects/new.html.erb`
- Modify: `app/views/projects/_form.html.erb`

**Step 1: Read current form**

```bash
cat app/views/projects/new.html.erb
cat app/views/projects/_form.html.erb
```

**Step 2: Update project new page**

Replace `app/views/projects/new.html.erb`:

```erb
<div class="max-w-md mx-auto px-4 py-12">
  <div class="mb-6">
    <%= link_to projects_path, class: "text-xs text-text-muted hover:text-text-secondary" do %>
      &larr; Projects
    <% end %>
  </div>

  <div class="bg-surface rounded-xl border border-border p-6">
    <h1 class="text-lg font-semibold mb-5">New Project</h1>
    <%= render "form", project: @project %>
  </div>
</div>
```

**Step 3: Update form partial**

Replace `app/views/projects/_form.html.erb`:

```erb
<%= form_with model: project, class: "space-y-5" do |f| %>
  <% if project.errors.any? %>
    <div class="bg-error-soft border border-error/20 rounded-lg p-4">
      <ul class="text-error text-sm space-y-1">
        <% project.errors.full_messages.each do |msg| %>
          <li><%= msg %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div>
    <%= f.label :name, class: "block text-xs font-medium text-text-secondary mb-1.5" %>
    <%= f.text_field :name,
        class: "w-full px-3 py-2 bg-base border border-border rounded-lg text-sm font-mono placeholder:text-text-muted focus:outline-none focus:border-accent focus:ring-2 focus:ring-accent/20 transition-all",
        placeholder: "my-project" %>
    <p class="text-xxs text-text-muted mt-1.5">A short identifier for your project</p>
  </div>

  <% if Current.account.servers.count > 1 %>
    <div>
      <%= f.label :server_id, "Server", class: "block text-xs font-medium text-text-secondary mb-1.5" %>
      <%= f.collection_select :server_id, Current.account.servers, :id, :name,
          {},
          class: "w-full px-3 py-2 bg-base border border-border rounded-lg text-sm focus:outline-none focus:border-accent focus:ring-2 focus:ring-accent/20 transition-all" %>
    </div>
  <% else %>
    <%= f.hidden_field :server_id, value: Current.account.servers.first&.id %>
  <% end %>

  <div class="flex justify-end gap-2 pt-2">
    <%= link_to "Cancel", projects_path, class: "px-4 py-2 text-xs text-text-secondary hover:text-text-primary rounded-lg" %>
    <%= f.submit project.persisted? ? "Update Project" : "Create Project",
        class: "px-4 py-2 bg-gradient-to-r from-accent to-accent-hover text-white text-xs font-medium rounded-lg shadow shadow-accent/20 cursor-pointer hover:opacity-90" %>
  </div>
<% end %>
```

**Step 4: Verify in browser**

Visit: http://localhost:3000/projects/new
Expected: Clean form with dark inputs, gradient submit button

**Step 5: Run tests**

Run: `bin/rails test`
Expected: All tests pass

**Step 6: Commit**

```bash
git add app/views/projects/new.html.erb app/views/projects/_form.html.erb
git commit -m "Update project forms with new input styles"
```

---

## Task 9: Update Remaining App Pages

**Files:**
- Modify: `app/views/projects/apps/overview/show.html.erb`
- Modify: `app/views/projects/apps/deployments/index.html.erb`
- Modify: `app/views/projects/apps/deployments/_deployment_row.html.erb`

**Step 1: Read current files and update systematically**

These follow the same patterns established above:
- Use `bg-surface rounded-xl border border-border` for cards
- Use `text-xs` and `text-xxs` for compact text
- Use `font-mono` for technical content
- Use gradient buttons for primary actions
- Use `hover:bg-elevated/30` for row hovers

**Step 2: Update each file following the established patterns**

(The specific implementations would follow the same style as Tasks 5-8)

**Step 3: Run tests after each file**

**Step 4: Commit incrementally**

---

## Task 10: Update Service Pages

**Files:**
- Modify: `app/views/projects/services/_header.html.erb`
- Modify: `app/views/projects/services/overview/show.html.erb`

Follow same patterns as app pages.

---

## Task 11: Update Activity Page

**Files:**
- Modify: `app/views/server_actions/index.html.erb`

Follow same patterns - dense table or list layout.

---

## Task 12: Update Account Settings

**Files:**
- Modify: `app/views/accounts/show.html.erb`

Follow same patterns - card-based sections.

---

## Task 13: Final Cleanup

**Files:**
- Remove any unused DaisyUI classes throughout codebase
- Update any remaining partials with old styles

**Step 1: Search for DaisyUI class patterns**

Run: `grep -r "btn-" app/views/` and similar patterns

**Step 2: Replace with new classes**

**Step 3: Full test run**

Run: `bin/rails test`
Expected: All 171 tests pass

**Step 4: Final commit**

```bash
git add -A
git commit -m "Complete UI redesign migration to vanilla Tailwind"
```

---

## Summary

After completing all tasks:

1. **Tailwind config** updated with custom theme
2. **Layout and nav** use glass effect and gradient logo
3. **Status helpers** use new color palette with glows
4. **Projects pages** use card grid and dense rows
5. **App pages** use segmented control tabs
6. **Forms** use dark inputs with accent focus states
7. **All DaisyUI** removed, pure Tailwind

Run full test suite to verify nothing broke:
```bash
bin/rails test
```

Then merge to main when ready.
