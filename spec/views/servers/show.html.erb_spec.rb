require "rails_helper"

RSpec.describe "servers/show", type: :view do
  before(:each) do
    assign(:server, Server.create!(
      provider: "Provider",
      name: "Name",
      dokku_token: "Dokku Token",
      status: "Status"
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Provider/)
    expect(rendered).to match(/Name/)
    expect(rendered).to match(/Dokku Token/)
    expect(rendered).to match(/Status/)
  end
end
