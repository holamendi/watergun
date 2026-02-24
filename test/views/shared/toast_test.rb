require "test_helper"

class ToastPartialTest < ActionView::TestCase
  test "renders success toast with message" do
    render partial: "shared/toast", locals: {message: "App created", type: :success, title: nil, link_text: nil, link_url: nil}

    assert_select ".toast-notification.toast-success"
    assert_select ".toast-accent"
    assert_select ".toast-progress"
    assert_select "p", text: "App created"
    assert_select ".toast-link", count: 0
  end

  test "renders notice toast" do
    render partial: "shared/toast", locals: {message: "Setting saved", type: :notice, title: nil, link_text: nil, link_url: nil}

    assert_select ".toast-notification.toast-notice"
    assert_select ".toast-accent"
  end

  test "renders error toast" do
    render partial: "shared/toast", locals: {message: "Something failed", type: :error, title: nil, link_text: nil, link_url: nil}

    assert_select ".toast-notification.toast-error"
    assert_select ".toast-accent"
  end

  test "renders unknown type as info" do
    render partial: "shared/toast", locals: {message: "Info message", type: :other, title: nil, link_text: nil, link_url: nil}

    assert_select ".toast-notification.toast-info"
  end

  test "renders title when present" do
    render partial: "shared/toast", locals: {message: "Details here", type: :notice, title: "Heads up", link_text: nil, link_url: nil}

    assert_select "p.font-semibold", text: "Heads up"
    assert_select "p", text: "Details here"
  end

  test "renders link when both link_text and link_url are present" do
    render partial: "shared/toast", locals: {message: "Service created", type: :success, title: nil, link_text: "View service", link_url: "/projects/1/services/2"}

    assert_select "a.toast-link[href='/projects/1/services/2']"
    assert_select "a.toast-link", /View service/
  end

  test "does not render link when link_text is missing" do
    render partial: "shared/toast", locals: {message: "Done", type: :notice, title: nil, link_text: nil, link_url: "/some/path"}

    assert_select ".toast-link", count: 0
  end

  test "does not render link when link_url is missing" do
    render partial: "shared/toast", locals: {message: "Done", type: :notice, title: nil, link_text: "View", link_url: nil}

    assert_select ".toast-link", count: 0
  end
end
