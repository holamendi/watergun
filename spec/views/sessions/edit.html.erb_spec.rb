require 'rails_helper'

RSpec.describe "sessions/edit", type: :view do
  let(:session) {
    Session.create!(
      user: nil,
      token: "MyString"
    )
  }

  before(:each) do
    assign(:session, session)
  end

  it "renders the edit session form" do
    render

    assert_select "form[action=?][method=?]", session_path(session), "post" do

      assert_select "input[name=?]", "session[user_id]"

      assert_select "input[name=?]", "session[token]"
    end
  end
end
