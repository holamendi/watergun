module TabsHelper
  def tab_link(text, path, active_condition, options = {})
    link_to(text, path, class: class_names(
      "px-1 py-4 text-sm font-medium whitespace-nowrap border-b-2",
      "border-teal-500 text-teal-600 border-teal-500" => active_condition,
      "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700" => !active_condition
    ), **options)
  end
end
