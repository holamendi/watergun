require "test_helper"
require "shellwords"

class Dokku::StorageCommandsTest < ActiveSupport::TestCase
  test "storage commands encode every untrusted argument as a single shell token" do
    app = "app; touch /tmp/no"
    host = "/data/a file$(id)"
    container = "/app/data;id"
    [Dokku::Storage::Mount, Dokku::Storage::UnmountCommand].each do |klass|
      command = klass.new(app: app, host_directory: host, container_directory: container)
      tokens = nil
      assert_nothing_raised { tokens = Shellwords.split(command.cmd) }
      assert_equal ["dokku", (klass == Dokku::Storage::Mount) ? "storage:mount" : "storage:unmount", app, "#{host}:#{container}"], tokens
      assert_includes command.cmd, "\\;"
    end
    assert_equal ["dokku", "storage:list", app, "--format", "json"], Shellwords.split(Dokku::Storage::ListCommand.new(app: app).cmd)
    assert_equal ["dokku", "ps:restart", app], Shellwords.split(Dokku::Ps::RestartCommand.new(app: app).cmd)
  end

  test "phase commands read and change only the requested phase" do
    assert_equal ["sudo", "-n", "dokku", "plugin:trigger", "storage-list", "app", "run", "json"], Shellwords.split(Dokku::Storage::ListCommand.new(app: "app", phase: "run").cmd)
    assert_equal ["dokku", "docker-options:add", "app", "run", "-v /host:/app/data"], Shellwords.split(Dokku::Storage::Mount.new(app: "app", host_directory: "/host", container_directory: "/app/data", phase: "run").cmd)
    assert_equal ["dokku", "docker-options:remove", "app", "deploy", "-v /host:/app/data"], Shellwords.split(Dokku::Storage::UnmountCommand.new(app: "app", host_directory: "/host", container_directory: "/app/data", phase: "deploy").cmd)
  end

  test "phase detach treats legacy paths as literal sed patterns and shell tokens" do
    require "open3"
    host = "/data/a file$(id);'[]#.^$"
    container = "/app/uploads/"
    command = Dokku::Storage::UnmountCommand.new(app: "app", host_directory: host, container_directory: container, phase: "run")
    tokens = Shellwords.split(command.cmd)
    assert_equal ["dokku", "docker-options:remove", "app", "run"], tokens.first(4)
    binding = "-v #{host}:#{container}"
    neighbor = "-v /data/other:/app/uploads/"
    # Dokku 0.36.7 remove_passed_docker_option interpolates this argument into
    # sed's basic regex, using # as the delimiter. Shell escaping alone is not enough.
    output, error, status = Open3.capture3("sed", "s#^#{tokens[4]}$##", stdin_data: "#{binding}\n#{neighbor}\n")
    assert status.success?, error
    assert_equal "\n#{neighbor}\n", output
  end

  test "ensure directory uses real subcommand and separate ownership flag" do
    command = Dokku::Storage::EnsureDirectory.new(directory: "watergun-123", chown: "heroku")
    assert_equal ["dokku", "storage:ensure-directory", "--chown", "heroku", "watergun-123"], Shellwords.split(command.cmd)
    assert_equal ["dokku", "storage:ensure-directory", "--chown", "false", "watergun-123"], Shellwords.split(Dokku::Storage::EnsureDirectory.new(directory: "watergun-123").cmd)
  end
end
