require 'rails_helper'

RSpec.describe "orgs/new", type: :view do
  before(:each) do
    assign(:org, Org.new(
      name: "MyString"
    ))
  end

  it "renders new org form" do
    render

    assert_select "form[action=?][method=?]", orgs_path, "post" do

      assert_select "input[name=?]", "org[name]"
    end
  end
end
