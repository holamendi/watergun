require 'rails_helper'

RSpec.describe "sessions/show", type: :view do
  before(:each) do
    assign(:session, Session.create!(
      user: nil,
      token: "Token"
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(//)
    expect(rendered).to match(/Token/)
  end
end
