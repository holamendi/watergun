module ApplicationHelper
  def status_color_class(status)
    case status
    when "success"
      "bg-green-50 text-green-700 ring-1 ring-inset ring-green-700/10"
    when "running"
      "bg-blue-50 text-blue-700 ring-1 ring-inset ring-blue-700/10"
    when "failed"
      "bg-red-50 text-red-700 ring-1 ring-inset ring-red-700/10"
    when "completed"
      "bg-green-50 text-green-700 ring-1 ring-inset ring-green-700/10"
    else
      "bg-gray-50 text-gray-700 ring-1 ring-inset ring-gray-700/10"
    end
  end

  def component(name, *, **, &)
    component = "#{name.to_s.camelize}Component".constantize
    render(component.new(*, **), &)
  end

  def page_header(title, actions = nil, &block)
    if block_given?
      actions = capture(&block)
    end

    render "shared/page_header", title: title, actions: actions || ""
  end

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
end
