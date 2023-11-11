require 'rails_helper'

RSpec.describe "orgs/edit", type: :view do
  let(:org) {
    Org.create!(
      name: "MyString"
    )
  }

  before(:each) do
    assign(:org, org)
  end

  it "renders the edit org form" do
    render

    assert_select "form[action=?][method=?]", org_path(org), "post" do

      assert_select "input[name=?]", "org[name]"
    end
  end
end
