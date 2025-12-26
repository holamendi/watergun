require "test_helper"

class Github::EventTest < ActiveSupport::TestCase
  setup do
    @event = github_events(:push_event)
  end

  test "slug returns event when no action" do
    assert_equal "push", @event.slug
  end

  test "slug combines event and action when present" do
    event = Github::Event.new(
      headers: {"HTTP_X_GITHUB_EVENT" => "installation"},
      payload: {"action" => "created"}
    )

    assert_equal "installation.created", event.slug
  end

  test "event returns event from headers" do
    assert_equal "push", @event.event
  end

  test "action returns action from payload" do
    event_with_action = Github::Event.new(
      headers: {},
      payload: {"action" => "created"}
    )

    assert_equal "created", event_with_action.action
  end

  test "processed? returns false when not processed" do
    refute @event.processed?
  end

  test "processed? returns true when processed" do
    event = github_events(:processed_event)
    assert event.processed?
  end

  test "processed scope only includes processed events" do
    processed_events = Github::Event.processed

    assert_includes processed_events, github_events(:processed_event)
    refute_includes processed_events, github_events(:push_event)
  end

  test "belongs to installation" do
    assert_equal github_installations(:default), @event.installation
  end

  test "belongs to account via default" do
    assert_equal accounts(:default), @event.account
  end
end
