require "test_helper"

class Dokku::Services::LinksCommandTest < ActiveSupport::TestCase
  test "cmd returns service links command" do
    command = Dokku::Services::LinksCommand.new(plugin: "postgres", service: "primary-db")

    assert_equal "dokku postgres:links primary-db", command.cmd
  end

  test "parse_output parses links" do
    output = <<~OUTPUT
      =====> primary-db links
      blog
      api
    OUTPUT

    command = Dokku::Services::LinksCommand.new(plugin: "postgres", service: "primary-db")

    assert_equal ["blog", "api"], command.parse_output(0, output)
  end

  test "parse_output returns an empty list for no linked apps" do
    output = "No linked apps\n"
    command = Dokku::Services::LinksCommand.new(plugin: "postgres", service: "primary-db")

    assert_equal [], command.parse_output(0, output)
  end

  test "parse_output returns an empty list on failure" do
    command = Dokku::Services::LinksCommand.new(plugin: "postgres", service: "primary-db")

    assert_equal [], command.parse_output(1, "error")
  end
end
