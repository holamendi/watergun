# frozen_string_literal: true

class PageHeaderComponent < ViewComponent::Base
  renders_one :actions

  def initialize(title:)
    @title = title
  end
end
