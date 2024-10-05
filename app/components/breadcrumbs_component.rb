class BreadcrumbsComponent < ViewComponent::Base
  def initialize(entries)
    @entries = entries.map { Array(_1) }
  end
end
