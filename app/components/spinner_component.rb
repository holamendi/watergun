# frozen_string_literal: true

class SpinnerComponent < ViewComponent::Base
  def initialize(size: 4, color: "emerald-500")
    @size = size
    @color = color
  end
end
