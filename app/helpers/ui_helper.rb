module UiHelper
  def container(&block)
    content_tag :div, class: "max-w-5xl px-4 mx-auto sm:px-6 lg:px-8" do
      yield
    end
  end

  def full_width_container(&block)
    content_tag :div, class: "w-full px-4 mx-auto sm:px-6 lg:px-8" do
      yield
    end
  end

  def page_header(title, actions = nil, &block)
    if block_given?
      actions = capture(&block)
    end

    render "shared/page_header", title: title, actions: actions.presence || ""
  end

  def badge(text, color: :gray)
    color_classes = {
      blue: "bg-blue-400/10 text-blue-400 ring-blue-400/30",
      gray: "bg-gray-400/10 text-gray-400 ring-gray-400/20",
      green: "bg-green-500/10 text-green-400 ring-green-500/20",
      indigo: "bg-indigo-400/10 text-indigo-400 ring-indigo-400/30",
      pink: "bg-pink-400/10 text-pink-400 ring-pink-400/20",
      purple: "bg-purple-400/10 text-purple-400 ring-purple-400/30",
      red: "bg-red-400/10 text-red-400 ring-red-400/20",
      yellow: "bg-yellow-400/10 text-yellow-500 ring-yellow-400/20"
    }

    content_tag :span, text, class: "inline-flex items-center rounded-md px-2 py-1 text-xs font-medium ring-1 ring-inset #{color_classes[color]}"
  end

  def status_badge(status)
    status_mapping = {
      "active" => :green,
      "deploying" => :blue,
      "error" => :red,
      "pending" => :yellow,
      "success" => :green
    }

    badge(status.humanize, color: status_mapping[status])
  end

  def spinner(size: "5", color: "gray-500")
    tag.svg(
      class: "size-#{size} text-#{color} animate-spin",
      xmlns: "http://www.w3.org/2000/svg",
      fill: "none",
      viewBox: "0 0 24 24"
    ) do
      concat tag.circle(
        class: "opacity-25",
        cx: "12",
        cy: "12",
        r: "10",
        stroke: "currentColor",
        "stroke-width": "4"
      )
      concat tag.path(
        class: "opacity-75",
        fill: "currentColor",
        d: "M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
      )
    end
  end

  def submit_button(text)
    button_tag text,
      class: "rounded-md bg-teal-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-teal-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-600",
      data: {
        turbo_submits_with: tag.span(class: "flex items-center gap-x-2") do
          concat spinner(color: "white")
          concat text
        end
      }
  end
end
