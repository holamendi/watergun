# Buttons & Links Improvement Design

## Problem

1. Missing `cursor-pointer` on interactive elements (buttons, links)
2. No loading states on form submit buttons
3. `UiHelper` still uses old DaisyUI classes from before the UI redesign
4. Inline Tailwind classes are verbose but acceptable while design is still evolving

## Approach

Keep it simple - fix the immediate UX issues without committing to a full component abstraction. We can build proper helpers later when the design stabilizes.

## Changes

### 1. Global cursor-pointer fix

Add to main CSS file using Tailwind's base layer:

```css
@layer base {
  button:not(:disabled),
  [role="button"]:not(:disabled),
  a[href],
  select:not(:disabled),
  input[type="checkbox"]:not(:disabled),
  input[type="radio"]:not(:disabled) {
    cursor: pointer;
  }
}
```

### 2. Update `submit_button` helper

Replace the current DaisyUI-based implementation in `app/helpers/ui_helper.rb`:

```ruby
def submit_button(text, variant: :primary)
  base_classes = "text-xs font-medium rounded transition-colors cursor-pointer"
  size_classes = "px-4 py-2"

  variant_classes = case variant
  when :primary
    "bg-gradient-to-r from-accent to-accent-hover text-white shadow shadow-accent/20"
  when :secondary
    "bg-elevated hover:bg-border text-text-primary border border-border"
  when :destructive
    "bg-error/20 text-error hover:bg-error/30"
  end

  disabled_classes = "disabled:opacity-50 disabled:cursor-not-allowed"

  button_tag text,
    class: "#{base_classes} #{size_classes} #{variant_classes} #{disabled_classes}",
    data: {
      turbo_submits_with: tag.span(class: "inline-flex items-center gap-2") do
        concat spinner_icon
        concat text
      end
    }
end

private

def spinner_icon
  tag.svg(class: "w-3 h-3 animate-spin", viewBox: "0 0 24 24", fill: "none") do
    concat tag.circle(cx: 12, cy: 12, r: 10, stroke: "currentColor", "stroke-width": 4, class: "opacity-25")
    concat tag.path(fill: "currentColor", d: "M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z", class: "opacity-75")
  end
end
```

**Features:**
- Uses new design system colors and spacing
- Shows spinner + text during Turbo form submission
- Supports `:primary`, `:secondary`, `:destructive` variants
- Proper disabled state styling

### 3. Remove unused `spinner` helper

The old `spinner` method uses DaisyUI classes and isn't used anywhere in templates. Remove it.

## Files to modify

- `app/assets/stylesheets/application.css` - Add base layer cursor styles
- `app/helpers/ui_helper.rb` - Update `submit_button`, add `spinner_icon`, remove `spinner`

## Future considerations

When the design stabilizes, consider adding:
- `ui_button` helper for non-submit buttons
- `ui_link` helper for consistent link styling
- `back_link` helper for "← Back to X" pattern
- `link_button` helper for links styled as buttons
