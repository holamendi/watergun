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
end
