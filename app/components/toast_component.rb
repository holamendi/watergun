class ToastComponent < ViewComponent::Base
  def initialize(title: nil, message: nil, type: :info)
    @title = title
    @message = message
    @type = type
  end
end
