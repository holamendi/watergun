module UiHelper
  def container(&block)
    content_tag :div, class: "page-shell", &block
  end

  def full_width_container(&block)
    content_tag :div, class: "w-full px-4 mx-auto sm:px-6 lg:px-8", &block
  end

  def page_header(title, actions = nil, &block)
    actions = capture(&block) if block_given?

    render "shared/page_header", title: title, actions: actions.presence || ""
  end

  def badge(text, color: :neutral)
    # Maps semantic colors to CSS badge modifier classes
    color_classes = {
      blue: "badge-info",
      gray: "badge-neutral",
      neutral: "badge-neutral",
      green: "badge-success",
      indigo: "badge-primary",
      pink: "badge-secondary",
      purple: "badge-accent",
      red: "badge-error",
      yellow: "badge-warning"
    }

    content_tag :span, text, class: "badge badge-sm #{color_classes[color]}"
  end

  def status_dot(status, size: 2)
    size_classes = {
      2 => "w-2 h-2",
      3 => "w-3 h-3",
      4 => "w-4 h-4",
      :md => "w-2.5 h-2.5"
    }

    color_class = case status.to_s
    when "running", "active", "success", "completed"
      "bg-success shadow-success/50"
    when "deploying", "pending", "warning"
      "bg-warning shadow-warning/50 animate-pulse"
    when "failed", "error"
      "bg-error shadow-error/50"
    else
      "bg-elevated"
    end

    tag.span(class: "#{size_classes.fetch(size, size_classes[2])} rounded-full #{color_class} shadow inline-block")
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

  def submit_button(text, variant: :primary, size: :default)
    base_classes = "inline-flex items-center justify-center gap-2 font-medium rounded transition-colors"

    size_classes = case size
    when :sm
      "px-3 py-1.5 text-xs"
    when :xs
      "px-2.5 py-1 text-xxs"
    else
      "px-4 py-2 text-xs"
    end

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
          concat spinner_icon(size)
          concat text
        end
      }
  end

  private

  def spinner_icon(size = :default)
    size_class = (size == :xs) ? "w-2.5 h-2.5" : "w-3 h-3"
    tag.svg(class: "#{size_class} animate-spin", viewBox: "0 0 24 24", fill: "none") do
      concat tag.circle(cx: 12, cy: 12, r: 10, stroke: "currentColor", "stroke-width": 4, class: "opacity-25")
      concat tag.path(fill: "currentColor", d: "M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z", class: "opacity-75")
    end
  end
end
