require 'rails_helper'

RSpec.describe "memberships/edit", type: :view do
  let(:membership) {
    Membership.create!(
      user: nil,
      org: nil
    )
  }

  before(:each) do
    assign(:membership, membership)
  end

  it "renders the edit membership form" do
    render

    assert_select "form[action=?][method=?]", membership_path(membership), "post" do

      assert_select "input[name=?]", "membership[user_id]"

      assert_select "input[name=?]", "membership[org_id]"
    end
  end
end
