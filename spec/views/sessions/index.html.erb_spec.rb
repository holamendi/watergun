require 'rails_helper'

RSpec.describe "sessions/index", type: :view do
  before(:each) do
    assign(:sessions, [
      Session.create!(
        user: nil,
        token: "Token"
      ),
      Session.create!(
        user: nil,
        token: "Token"
      )
    ])
  end

  it "renders a list of sessions" do
    render
    cell_selector = Rails::VERSION::STRING >= '7' ? 'div>p' : 'tr>td'
    assert_select cell_selector, text: Regexp.new(nil.to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Token".to_s), count: 2
  end
end
