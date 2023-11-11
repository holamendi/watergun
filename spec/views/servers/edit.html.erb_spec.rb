require "rails_helper"

RSpec.describe "servers/edit", type: :view do
  let(:server) {
    Server.create!(
      provider: "MyString",
      name: "MyString",
      dokku_token: "MyString",
      status: "MyString"
    )
  }

  before(:each) do
    assign(:server, server)
  end

  it "renders the edit server form" do
    render

    assert_select "form[action=?][method=?]", server_path(server), "post" do
      assert_select "input[name=?]", "server[provider]"

      assert_select "input[name=?]", "server[name]"

      assert_select "input[name=?]", "server[dokku_token]"

      assert_select "input[name=?]", "server[status]"
    end
  end
end
