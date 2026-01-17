# Watergun UI Redesign: Hybrid Dense

## Overview

A new visual direction for Watergun that combines information density with a warmer, more polished aesthetic. Moving from DaisyUI to vanilla Tailwind for full control.

**Key influences:**
- Railway (terminal aesthetic, dense but readable)
- Linear (fast, opinionated)
- macOS (rounded corners, vibrancy, "happier" feel)

**Design goals:**
- Dense layouts that show all relevant info at a glance
- Rounded but not bubbly (6-8px radius)
- Vibrant accent colors with subtle glows
- Fast, capable, approachable

---

## Design Foundation

### Color Palette

**Background layers** (darkest to lightest):
| Token | Hex | Usage |
|-------|-----|-------|
| `base` | #121218 | Page background |
| `surface` | #1a1a22 | Cards, panels |
| `elevated` | #24242e | Hover states, nested elements |
| `border` | #2e2e3a | Subtle dividers |
| `border-strong` | #3e3e4a | Emphasis borders |

**Text hierarchy:**
| Token | Hex | Usage |
|-------|-----|-------|
| `text-primary` | #f0f0f5 | Main content |
| `text-secondary` | #9898a8 | Labels, metadata |
| `text-muted` | #606070 | Disabled, hints |

**Accent colors** (vibrant, used sparingly):
| Token | Hex | Usage |
|-------|-----|-------|
| `accent` | #6c5ce7 | Primary actions, links |
| `success` | #00cec9 | Running, healthy |
| `warning` | #fdcb6e | Deploying, attention |
| `error` | #ff7675 | Failed, destructive |
| `pink` | #fd79a8 | Gradients, highlights |

### Typography

- **UI text:** Inter, 13px base
- **Technical content:** JetBrains Mono (app names, commits, SHAs, env vars, logs)
- **Compact sizing:** Some labels at 10px (`text-xxs`)
- **Font weights:** 400 body, 500 medium, 600 semibold

### Spacing & Radius

- **Spacing:** Tight - 8-12px gaps, 12-16px card padding
- **Border radius:** 6px default, 8px large (`rounded-lg`), 10px extra-large (`rounded-xl`)

---

## Components

### Buttons

**Primary:**
```html
<button class="px-4 py-2 bg-gradient-to-r from-accent to-accent-hover text-white text-xs font-medium rounded-lg shadow shadow-accent/20">
  Deploy
</button>
```

**Secondary:**
```html
<button class="px-4 py-2 bg-elevated hover:bg-border text-text-primary text-xs font-medium rounded-lg border border-border">
  Restart
</button>
```

**Destructive:**
```html
<button class="px-4 py-2 bg-error/20 text-error text-xs font-medium rounded-lg hover:bg-error/30">
  Delete
</button>
```

**Ghost:**
```html
<button class="px-4 py-2 text-text-secondary hover:text-text-primary text-xs font-medium rounded-lg">
  Cancel
</button>
```

### Status Indicators

Small dots (w-2 h-2) with colored glow shadows:

```html
<!-- Running -->
<span class="w-2 h-2 rounded-full bg-success shadow shadow-success/50"></span>

<!-- Deploying -->
<span class="w-2 h-2 rounded-full bg-warning shadow shadow-warning/50 animate-pulse"></span>

<!-- Failed -->
<span class="w-2 h-2 rounded-full bg-error shadow shadow-error/50"></span>

<!-- Stopped -->
<span class="w-2 h-2 rounded-full bg-text-muted"></span>
```

### Cards

```html
<a href="#" class="bg-surface rounded-xl border border-border p-4 hover:border-accent/50 hover:shadow-lg hover:shadow-accent/10 transition-all">
  <!-- Gradient avatar -->
  <div class="w-8 h-8 rounded-lg bg-gradient-to-br from-accent to-pink flex items-center justify-center text-white text-xs font-bold">M</div>
  <!-- Content -->
</a>
```

### Tables

Dense tables with hover states:

```html
<table class="w-full text-xs">
  <thead>
    <tr class="border-b border-border bg-elevated/50 text-text-muted">
      <th class="text-left px-3 py-2 font-medium">...</th>
    </tr>
  </thead>
  <tbody class="divide-y divide-border">
    <tr class="hover:bg-elevated/30 transition-colors">
      <td class="px-3 py-2">...</td>
    </tr>
    <!-- Failed row -->
    <tr class="hover:bg-elevated/30 bg-error/20">...</tr>
  </tbody>
</table>
```

### Navigation

Glass effect top bar:

```html
<div class="glass rounded-xl border border-border">
  <!-- glass class: background: rgba(26, 26, 34, 0.8); backdrop-filter: blur(12px); -->
</div>
```

Gradient logo text:
```html
<span class="font-semibold bg-gradient-to-r from-accent to-pink bg-clip-text text-transparent">Watergun</span>
```

### Tabs (Segmented Control)

```html
<div class="inline-flex bg-elevated rounded-lg p-0.5">
  <button class="px-3 py-1.5 text-xs text-text-primary bg-surface rounded-md shadow-sm font-medium">Active</button>
  <button class="px-3 py-1.5 text-xs text-text-secondary hover:text-text-primary rounded-md">Inactive</button>
</div>
```

### Metrics

Compact metric cards with sparkline:

```html
<div class="bg-surface rounded-xl border border-border p-3">
  <div class="flex items-center justify-between mb-2">
    <span class="text-xxs text-text-muted uppercase">CPU</span>
    <span class="text-xs font-medium text-warning">67%</span>
  </div>
  <div class="h-1.5 bg-elevated rounded-full overflow-hidden">
    <div class="h-full bg-gradient-to-r from-warning to-error rounded-full" style="width: 67%"></div>
  </div>
  <!-- Mini sparkline bars -->
</div>
```

---

## Layout Patterns

### Information Density

**Stats bar** at top of dashboards: 6-column grid showing key metrics.

**Tables** as default for lists with many attributes. Show all relevant columns inline: status, name, branch, processes, CPU, memory, timestamp, actions.

**Row-style lists** for simpler cases: icon + name + metadata on left, metrics + actions on right.

**Split panels** for related data: apps on left, services on right.

### Progressive Disclosure

1. **Overview** shows essentials (status, name, key metrics, quick actions)
2. **Click through** to detail page with full controls
3. **Tabs** on detail pages: Deployments, Logs, Variables, Domains, Settings
4. **Overflow menu** (⋮) for less common actions

### Responsive

- Tables scroll horizontally on mobile
- Stats bar collapses to 3x2 grid
- Navigation collapses to hamburger menu

---

## Implementation

### Tailwind Configuration

Remove DaisyUI. Add to `tailwind.config.js`:

```javascript
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
      warning: '#fdcb6e',
      error: '#ff7675',
      pink: '#fd79a8',
    },
    fontFamily: {
      sans: ['Inter', 'system-ui', 'sans-serif'],
      mono: ['JetBrains Mono', 'monospace'],
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
}
```

### Helper Updates

Update `app/helpers/ui_helper.rb`:
- `status_dot(status)` - colored dot with glow shadow
- `status_badge(status)` - soft background pill

### Migration Order

1. Update Tailwind config with new theme
2. Update application layout and nav (sets the tone)
3. Projects index (dashboard with cards)
4. Project show (app/service lists)
5. App show (tabs, deployments, metrics)
6. Service show
7. Forms and settings pages
8. Extract repeated patterns into partials

### Preview Files

Static HTML previews created during design:
- `tmp/ui-preview-hybrid.html` - final direction
- `tmp/ui-preview.html` through `tmp/ui-preview-brutalist.html` - alternatives explored

---

## References

- [Railway](https://railway.app) - terminal aesthetic, dense layouts
- [Linear](https://linear.app) - keyboard-first, fast, opinionated
- [Tailwind CSS](https://tailwindcss.com/docs) - utility classes reference
