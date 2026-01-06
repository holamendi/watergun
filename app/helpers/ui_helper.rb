module UiHelper
  def container(&block)
    content_tag :div, class: "max-w-5xl px-4 mx-auto sm:px-6 lg:px-8", &block
  end

  def full_width_container(&block)
    content_tag :div, class: "w-full px-4 mx-auto sm:px-6 lg:px-8", &block
  end

  def page_header(title, actions = nil, &block)
    actions = capture(&block) if block_given?

    render "shared/page_header", title: title, actions: actions.presence || ""
  end

  def badge(text, color: :neutral)
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

  def status_badge(status)
    status_mapping = {
      "active" => :green,
      "cancelled" => :neutral,
      "deleting" => :yellow,
      "deploying" => :blue,
      "enabling_ssl" => :blue,
      "error" => :red,
      "failure" => :red,
      "pending" => :yellow,
      "queued" => :yellow,
      "running" => :blue,
      "success" => :green
    }

    badge(status.humanize, color: status_mapping[status])
  end

  def spinner(size: "md", color: nil)
    size_class = case size.to_s
    when "3", "4", "xs" then "loading-xs"
    when "5", "sm" then "loading-sm"
    when "6", "md" then "loading-md"
    else "loading-lg"
    end

    color_class = (color == "white") ? "text-white" : ""

    tag.span(class: "loading loading-spinner #{size_class} #{color_class}".strip)
  end

  def submit_button(text)
    button_tag text,
      class: "btn btn-primary btn-sm",
      data: {
        turbo_submits_with: tag.span(class: "flex items-center gap-2") do
          concat tag.span(class: "loading loading-spinner loading-xs")
          concat text
        end
      }
  end
end
