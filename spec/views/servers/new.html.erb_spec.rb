require "rails_helper"

RSpec.describe "servers/new", type: :view do
  before(:each) do
    assign(:server, Server.new(
      provider: "MyString",
      name: "MyString",
      dokku_token: "MyString",
      status: "MyString"
    ))
  end

  it "renders new server form" do
    render

    assert_select "form[action=?][method=?]", servers_path, "post" do
      assert_select "input[name=?]", "server[provider]"

      assert_select "input[name=?]", "server[name]"

      assert_select "input[name=?]", "server[dokku_token]"

      assert_select "input[name=?]", "server[status]"
    end
  end
end
