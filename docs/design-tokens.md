# Watergun Design Tokens

Quick reference for implementing the design system. See `docs/design-system.html` for visual examples.

## Colors

```
Background layers (dark to light):
  base:          #121218   Page background
  surface:       #1a1a22   Cards, panels
  elevated:      #24242e   Hover states, nested elements
  border:        #2e2e3a   Subtle dividers
  border-strong: #3e3e4a   Emphasis borders

Text hierarchy:
  text-primary:   #f0f0f5   Main content
  text-secondary: #9898a8   Labels, metadata
  text-muted:     #606070   Disabled, hints

Accent colors:
  accent:       #f43f5e   Primary actions, links (rose)
  accent-hover: #fb7185   Hover state
  success:      #00cec9   Running, healthy
  warning:      #fdcb6e   Deploying, attention
  error:        #ff7675   Failed, destructive
  pink:         #fd79a8   Gradients
  cyan:         #00b894   Gradients
```

## Typography

- **UI text**: Inter, 13px base (`text-xs` = 12px, `text-xxs` = 10px)
- **Monospace**: JetBrains Mono (app names, commits, SHAs, logs, code)
- **Font weights**: 400 normal, 500 medium, 600 semibold

## Spacing & Radius

- **Spacing**: Tight - 8-12px gaps, 12-16px card padding
- **Border radius**: `rounded` (4px default), `rounded-sm` (2px for buttons/inputs)

## Component Patterns

### Buttons

```html
<!-- Primary -->
<button class="px-4 py-2 bg-gradient-to-r from-accent to-accent-hover text-white text-xs rounded shadow shadow-accent/20">
  Deploy
</button>

<!-- Secondary -->
<button class="px-4 py-2 bg-elevated hover:bg-border text-text-primary text-xs rounded border border-border">
  Restart
</button>

<!-- Ghost -->
<button class="px-4 py-2 text-text-secondary hover:text-text-primary text-xs rounded">
  Cancel
</button>

<!-- Destructive -->
<button class="px-4 py-2 bg-error/20 text-error text-xs rounded hover:bg-error/30">
  Delete
</button>

<!-- Small -->
<button class="px-2.5 py-1 bg-accent hover:bg-accent-hover text-white rounded text-xxs">
  Deploy
</button>

<!-- Loading (disabled with spinner) -->
<button disabled class="px-4 py-2 bg-gradient-to-r from-accent to-accent-hover text-white/70 text-xs rounded cursor-not-allowed inline-flex items-center gap-2">
  <svg class="w-3 h-3 animate-spin" viewBox="0 0 24 24" fill="none">
    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
  </svg>
  Deploying...
</button>
```

### Status Indicators

```html
<!-- Dots with glow -->
<span class="w-2 h-2 rounded-full bg-success shadow-lg shadow-success/50"></span>     <!-- Running -->
<span class="w-2 h-2 rounded-full bg-warning shadow-lg shadow-warning/50 animate-pulse"></span>  <!-- Deploying -->
<span class="w-2 h-2 rounded-full bg-error shadow-lg shadow-error/50"></span>          <!-- Failed -->
<span class="w-2 h-2 rounded-full bg-text-muted"></span>                               <!-- Stopped -->

<!-- Badges -->
<span class="px-2 py-0.5 bg-success/20 text-success text-xxs font-medium rounded">Active</span>
<span class="px-2 py-0.5 bg-warning/20 text-warning text-xxs font-medium rounded">Pending</span>
<span class="px-2 py-0.5 bg-error/20 text-error text-xxs font-medium rounded">Error</span>
<span class="px-2 py-0.5 bg-elevated text-text-secondary text-xxs font-medium rounded">main</span>
```

### Cards

```html
<a href="#" class="group bg-surface rounded border border-border p-4 hover:border-accent/50 hover:shadow-lg hover:shadow-accent/10 transition-all">
  <!-- Content -->
</a>
```

### Segmented Control (Tabs)

```html
<div class="inline-flex bg-elevated rounded p-0.5">
  <button class="px-3 py-1.5 text-xs text-text-primary bg-surface rounded-sm shadow-sm font-medium">Active</button>
  <button class="px-3 py-1.5 text-xs text-text-secondary hover:text-text-primary rounded-sm">Inactive</button>
</div>
```

### Form Inputs

```html
<input type="text" class="w-full px-3 py-2 bg-base border border-border rounded text-sm font-mono placeholder:text-text-muted focus:outline-none focus:border-accent focus:ring-2 focus:ring-accent/20 transition-all">

<select class="w-full px-3 py-2 bg-base border border-border rounded text-sm focus:outline-none focus:border-accent focus:ring-2 focus:ring-accent/20 transition-all">
  <option>Option</option>
</select>

<!-- Disabled -->
<input type="text" disabled class="w-full px-3 py-2 bg-elevated border border-border rounded text-sm font-mono text-text-muted cursor-not-allowed">
```

### Tables

```html
<table class="w-full text-xs">
  <thead>
    <tr class="border-b border-border bg-elevated/50 text-text-muted">
      <th class="text-left px-3 py-2 font-medium">Column</th>
    </tr>
  </thead>
  <tbody class="divide-y divide-border">
    <tr class="hover:bg-elevated/30 transition-colors">
      <td class="px-3 py-2">Content</td>
    </tr>
    <!-- Error row -->
    <tr class="hover:bg-elevated/30 bg-error/10">
      <td class="px-3 py-2">Failed item</td>
    </tr>
  </tbody>
</table>
```

### Navigation

```html
<!-- Glass navbar -->
<nav class="glass border-b border-border sticky top-0 z-50">
  <!-- glass = background: rgba(26, 26, 34, 0.8); backdrop-filter: blur(12px); -->
</nav>

<!-- Gradient logo -->
<span class="font-semibold bg-gradient-to-r from-accent to-pink bg-clip-text text-transparent">Watergun</span>

<!-- Nav links -->
<a href="#" class="px-3 py-1.5 text-xs text-text-secondary hover:text-text-primary rounded">Link</a>

<!-- Back link (chevron + context) -->
<a href="#" class="text-sm text-text-muted hover:text-text-secondary inline-flex items-center gap-1">
  <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor">
    <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5 8.25 12l7.5-7.5" />
  </svg>
  Context Name
</a>
```

### Gradient Avatars

```html
<div class="w-8 h-8 rounded bg-gradient-to-br from-accent to-pink flex items-center justify-center text-white text-xs font-bold">Y</div>
<div class="w-8 h-8 rounded bg-gradient-to-br from-warning to-error flex items-center justify-center text-white text-xs font-bold">H</div>
<div class="w-8 h-8 rounded bg-gradient-to-br from-success to-cyan flex items-center justify-center text-white text-xs font-bold">S</div>
```

### Section Headers

```html
<h2 class="text-xxs font-medium text-text-muted uppercase tracking-wider mb-4">Section Title</h2>
```

### Danger Zone

```html
<section class="pt-6 border-t border-border">
  <h2 class="text-sm font-medium text-error">Danger zone</h2>
  <p class="text-xs text-text-muted mt-1">
    Destructive action description here.
  </p>
  <button class="mt-4 px-4 py-2 bg-transparent border border-error text-error text-xs rounded hover:bg-error/10 transition-colors">
    Delete item
  </button>
</section>
```

### Form Layouts

```html
<!-- Centered form card (new/edit pages) -->
<div class="max-w-sm mx-auto px-4 py-12">
  <div class="mb-6">
    <!-- Back link -->
  </div>
  <div class="bg-surface rounded-xl border border-border p-6">
    <h1 class="text-lg font-semibold mb-5">Page Title</h1>
    <!-- Form content -->
  </div>
</div>

<!-- Inline field with save (settings pattern) -->
<div class="flex gap-3 items-end">
  <div class="flex-1">
    <label class="block text-xs font-medium text-text-secondary mb-1.5">Field name</label>
    <input type="text" class="w-full px-3 py-2 bg-base border border-border rounded text-sm font-mono focus:outline-none focus:border-accent focus:ring-2 focus:ring-accent/20 transition-all">
  </div>
  <button class="px-4 py-2 bg-gradient-to-r from-accent to-accent-hover text-white text-xs rounded shadow shadow-accent/20">Save</button>
</div>
```
