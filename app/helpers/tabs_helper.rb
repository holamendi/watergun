module TabsHelper
  def tab_link(text, path, active_condition, options = {})
    link_to(text, path, class: class_names(
      "tab",
      "tab-active" => active_condition
    ), role: "tab", **options)
  end
end
