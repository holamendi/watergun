module UiHelper
  UI_BUTTON_VARIANTS = {
    primary: "btn-primary",
    secondary: "btn-secondary",
    ghost: "btn-ghost",
    danger: "btn-danger",
    destructive: "btn-danger"
  }.freeze

  UI_BUTTON_SIZES = {
    xs: "btn-xs",
    sm: "btn-sm",
    md: nil,
    default: nil
  }.freeze

  # Configuration controls keep their geometry separate from visual variants.
  def config_action(text = nil, variant: :primary, icon: nil, label: nil, type: :button, class: nil, **options, &block)
    css_class = binding.local_variable_get(:class)
    compact = variant != :primary || icon.present?
    classes = class_names("config-action", compact ? "config-action-compact" : "config-action-primary", ("config-icon" if icon.present?), css_class)
    if icon.present?
      icon_button(label: label, icon: icon, variant: variant, size: :md, type: type, class: classes, **options)
    elsif type.to_sym == :submit
      submit_button(text, variant: variant, class: classes, **options, &block)
    else
      button(text, variant: variant, size: :sm, class: classes, **options, &block)
    end
  end

  def config_modal_trigger(text, modal_id:, **options)
    modal_trigger(text, modal_id: modal_id, class: "config-action config-action-primary", **options)
  end

  def config_close_button
    config_action(label: "Close dialog", variant: :ghost, type: :submit,
      icon: tag.svg(tag.path(d: "M6 18 18 6M6 6l12 12", "stroke-linecap": "round", "stroke-linejoin": "round"), viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", "stroke-width": "1.5"))
  end

  def config_modal_footer(submit:, variant: :primary)
    render "shared/ui/config_modal_footer", submit: submit, variant: variant
  end

  def row_actions(id:, label:, &block)
    render "shared/ui/row_actions", id: id, label: label, &block
  end

  def container(&block)
    content_tag :div, class: "page-shell", &block
  end

  def full_width_container(&block)
    content_tag :div, class: "w-full px-4 mx-auto sm:px-6 lg:px-8", &block
  end

  def page_header(title:, subtitle: nil, actions: nil, &block)
    actions = capture(&block) if block_given?

    render "shared/ui/page_header", title: title, subtitle: subtitle, actions: actions.presence
  end

  def empty_state(title:, body: nil, icon: nil, actions: nil, &block)
    actions = capture(&block) if block_given?

    render "shared/ui/empty_state", title: title, body: body, icon: icon, actions: actions.presence
  end

  def danger_zone(title:, description:, actions: nil, &block)
    actions = capture(&block) if block_given?

    render "shared/ui/danger_zone", title: title, description: description, actions: actions.presence
  end

  def back_link(text, path, icon: nil, class: nil, **options)
    css_class = binding.local_variable_get(:class)
    link_data = normalize_ui_data(options.delete(:data), component: "back-link")
    default_icon = tag.svg(
      tag.path("stroke-linecap": "round", "stroke-linejoin": "round", d: "M15.75 19.5 8.25 12l7.5-7.5"),
      class: "w-3.5 h-3.5", fill: "none", viewBox: "0 0 24 24", "stroke-width": "2", stroke: "currentColor"
    )
    icon_content = icon || default_icon

    link_to path,
      class: class_names("btn btn-ghost btn-xs rounded-md font-normal pl-0.5 pr-2", css_class),
      data: link_data,
      **options do
      safe_join([
        tag.span(icon_content, class: "inline-flex items-center", "aria-hidden": true),
        tag.span(text)
      ])
    end
  end

  def modal(id:, title:, frame: nil, &block)
    render "shared/modal", id: id, title: title, frame: frame, &block
  end

  def modal_frame(frame_id, title:, &block)
    render "shared/modal_frame", frame_id: frame_id, title: title, &block
  end

  def modal_trigger(text = nil, modal_id:, variant: :primary, size: :sm, class: nil, data: {}, **options, &block)
    css_class = binding.local_variable_get(:class)
    trigger_data = normalize_ui_data(data, component: "modal-trigger")
    trigger_data[:controller] = merge_data_tokens(trigger_data[:controller], "dialog-trigger")
    trigger_data[:action] = merge_data_tokens(trigger_data[:action], "click->dialog-trigger#open")
    trigger_data[:dialog_trigger_target_value] = modal_id

    button(text,
      variant: variant,
      size: size,
      type: :button,
      class: css_class,
      data: trigger_data,
      **options,
      &block)
  end

  def button(text = nil, href: nil, variant: :primary, size: :md, type: :button,
    class: nil, data: {}, method: nil, disabled: false, turbo_submits_with: nil,
    **options, &block)
    css_class = binding.local_variable_get(:class)
    content = block_given? ? capture(&block) : text
    classes = class_names("btn", button_size_class(size), button_variant_class(variant), css_class)

    if href.present?
      link_data = normalize_ui_data(data, component: "button")
      link_data[:turbo_method] = method if method.present?
      link_options = options.merge(class: classes, data: link_data)

      link_to(content, href, **link_options)
    else
      button_data = normalize_ui_data(data, component: "button")
      button_data[:turbo_submits_with] = turbo_submits_with if turbo_submits_with.present?

      button_tag content,
        type: type,
        class: classes,
        data: button_data,
        disabled: disabled,
        **options
    end
  end

  def icon_button(label:, href: nil, icon: nil, variant: :ghost, size: :sm, type: :button,
    class: nil, data: {}, **options, &block)
    css_class = binding.local_variable_get(:class)
    icon_content = block_given? ? capture(&block) : icon
    icon_content ||= "+"

    aria_options = (options.delete(:aria) || {}).dup
    aria_options[:label] ||= label

    button(nil,
      href: href,
      variant: variant,
      size: size,
      type: type,
      class: class_names("btn-square", css_class),
      data: normalize_ui_data(data, component: "icon-button"),
      aria: aria_options,
      **options) do
      content_tag(:span,
        icon_content,
        class: class_names("inline-flex items-center justify-center", icon_size_class(size)),
        "aria-hidden": true)
    end
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

  def env_variable_dot_color(status)
    case status.to_s
    when "running", "active", "success", "completed"
      "bg-success"
    when "deploying", "pending", "warning"
      "bg-warning animate-pulse"
    when "failed", "error"
      "bg-error"
    else
      "bg-text-muted"
    end
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

  def submit_button(text, variant: :primary, size: :sm, **options)
    ui_size = normalize_ui_size(size)
    turbo_submits_with = options.delete(:turbo_submits_with) || turbo_submit_content(text, ui_size)

    button(text,
      variant: variant,
      size: ui_size,
      type: :submit,
      turbo_submits_with: turbo_submits_with,
      **options)
  end

  private

  def normalize_ui_data(data, component:)
    normalized = (data || {}).dup
    normalized[:ui_component] ||= component
    normalized
  end

  def merge_data_tokens(existing, value)
    [existing, value].compact.flat_map { |entry| entry.to_s.split(/\s+/) }.reject(&:blank?).uniq.join(" ")
  end

  def normalize_ui_variant(variant)
    value = variant.to_s.downcase.to_sym
    return :danger if value == :destructive

    value
  end

  def normalize_ui_size(size)
    value = size.to_s.downcase.to_sym
    (value == :default) ? :md : value
  end

  def button_variant_class(variant)
    UI_BUTTON_VARIANTS.fetch(normalize_ui_variant(variant), UI_BUTTON_VARIANTS[:secondary])
  end

  def button_size_class(size)
    UI_BUTTON_SIZES.fetch(normalize_ui_size(size), UI_BUTTON_SIZES[:md])
  end

  def icon_size_class(size)
    case normalize_ui_size(size)
    when :xs then "w-3 h-3"
    when :md then "w-4 h-4"
    else "w-3.5 h-3.5"
    end
  end

  def turbo_submit_content(text, size)
    tag.span(class: "inline-flex items-center gap-2") do
      concat spinner_icon(size)
      concat text
    end
  end

  def spinner_icon(size = :md)
    size_class = (normalize_ui_size(size) == :xs) ? "w-2.5 h-2.5" : "w-3 h-3"

    tag.svg(class: "#{size_class} animate-spin", viewBox: "0 0 24 24", fill: "none") do
      concat tag.circle(cx: 12, cy: 12, r: 10, stroke: "currentColor", "stroke-width": 4, class: "opacity-25")
      concat tag.path(fill: "currentColor", d: "M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z", class: "opacity-75")
    end
  end
end
