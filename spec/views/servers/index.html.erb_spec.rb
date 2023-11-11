require "rails_helper"

RSpec.describe "servers/index", type: :view do
  before(:each) do
    assign(:servers, [
      Server.create!(
        provider: "Provider",
        name: "Name",
        dokku_token: "Dokku Token",
        status: "Status"
      ),
      Server.create!(
        provider: "Provider",
        name: "Name",
        dokku_token: "Dokku Token",
        status: "Status"
      )
    ])
  end

  it "renders a list of servers" do
    render
    cell_selector = (Rails::VERSION::STRING >= "7") ? "div>p" : "tr>td"
    assert_select cell_selector, text: Regexp.new("Provider".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Name".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Dokku Token".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Status".to_s), count: 2
  end
end
