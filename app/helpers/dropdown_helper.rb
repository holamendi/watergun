module DropdownHelper
  def dropdown(text:, items:, button_classes: nil)
    render partial: "shared/dropdown", locals: {
      text:,
      items:,
      button_classes:
    }
  end
end
