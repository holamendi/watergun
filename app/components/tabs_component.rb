class TabsComponent < ViewComponent::Base
  Tab = Data.define(:title, :path, :prefetch, :current) do
    def initialize(title:, path:, prefetch: true, current: false) = super
  end

  attr_reader :tabs

  def initialize(tabs)
    @tabs = tabs.map { Tab.new(**_1) }
  end
end
