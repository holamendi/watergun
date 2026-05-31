require "test_helper"

class Dokku::Services::InfoCommandTest < ActiveSupport::TestCase
  test "cmd returns service info command" do
    command = Dokku::Services::InfoCommand.new(plugin: "postgres", service: "primary-db")

    assert_equal "dokku postgres:info primary-db", command.cmd
  end

  test "parse_output returns service info" do
    output = <<~OUTPUT
      Dsn:                 postgres://primary-db:secret@dokku-postgres-primary-db:5432/primary-db
      Version:             16
      Links:               blog api
    OUTPUT

    command = Dokku::Services::InfoCommand.new(plugin: "postgres", service: "primary-db")
    info = command.parse_output(0, output)

    assert_equal "postgres://primary-db:secret@dokku-postgres-primary-db:5432/primary-db", info[:dsn]
    assert_equal "16", info[:version]
    assert_equal "blog api", info[:links]
  end

  test "parse_output returns nil on failure" do
    command = Dokku::Services::InfoCommand.new(plugin: "postgres", service: "primary-db")

    assert_nil command.parse_output(1, "error")
  end
end
