require 'rails_helper'

RSpec.describe "orgs/show", type: :view do
  before(:each) do
    assign(:org, Org.create!(
      name: "Name"
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Name/)
  end
end
