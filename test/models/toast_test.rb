require "test_helper"

class ToastTest < ActiveSupport::TestCase
  test "broadcasts toast to user" do
    user = users(:bobby)

    Turbo::StreamsChannel.expects(:broadcast_append_to).with(
      [user, :toasts],
      target: "toasts",
      partial: "shared/toast",
      locals: {message: "Hello", type: :notice, title: nil, link_text: nil, link_url: nil}
    )

    Toast.append_to_user(user, "Hello")
  end

  test "broadcasts toast with link" do
    user = users(:bobby)

    Turbo::StreamsChannel.expects(:broadcast_append_to).with(
      [user, :toasts],
      target: "toasts",
      partial: "shared/toast",
      locals: {message: "Created", type: :success, title: nil, link_text: "View it", link_url: "/some/path"}
    )

    Toast.append_to_user(user, "Created", type: :success, link_text: "View it", link_url: "/some/path")
  end
end
