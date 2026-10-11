require "test_helper"
require "shellwords"

class Dokku::Domains::RemoveCommandTest < ActiveSupport::TestCase
  test "preserves untrusted application and domain values as literal shell arguments" do
    app = "my-app; echo unexpected"
    domains = ["example.com; echo unexpected", "$(echo unexpected).example.com", "*.example.com"]
    command = Dokku::Domains::RemoveCommand.new(app: app, domain: domains)

    assert_equal ["dokku", "domains:remove", app, *domains], Shellwords.split(command.cmd)
    assert_includes command.cmd, '\\*.example.com'
  end
end
