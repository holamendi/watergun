class SubmitButtonComponent < ViewComponent::Base
  def initialize(text: "Save")
    @text = text
  end
end
