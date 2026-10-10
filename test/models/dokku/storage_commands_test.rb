require "test_helper"
require "shellwords"

class Dokku::StorageCommandsTest < ActiveSupport::TestCase
  test "named storage commands shell encode arguments and converge both phases in one mount" do
    app = "app; touch /tmp/no"
    entry = "legacy-123"
    container = "/app/a file$(id);'[]#.^$/"
    assert_equal ["sudo", "-n", "dokku", "plugin:trigger", "storage-app-mounts", app, "run"], Shellwords.split(Dokku::Storage::ListCommand.new(app: app, phase: "run").cmd)
    assert_equal ["dokku", "storage:mount", app, entry, "--container-dir", container, "--phase", "deploy", "--phase", "run"], Shellwords.split(Dokku::Storage::Mount.new(app: app, entry_name: entry, container_directory: container).cmd)
    assert_equal ["dokku", "storage:unmount", app, entry, "--container-dir", container], Shellwords.split(Dokku::Storage::UnmountCommand.new(app: app, entry_name: entry, container_directory: container).cmd)
    assert_equal ["dokku", "ps:restart", app], Shellwords.split(Dokku::Ps::RestartCommand.new(app: app).cmd)
  end

  test "entry creation encodes ownership separately and never chowns a custom path" do
    assert_equal ["dokku", "storage:create", "watergun-123", "--chown", "heroku"], Shellwords.split(Dokku::Storage::CreateEntry.new(name: "watergun-123", chown: "heroku").cmd)
    assert_equal ["dokku", "storage:create", "watergun-123", "--chown", "false"], Shellwords.split(Dokku::Storage::CreateEntry.new(name: "watergun-123").cmd)
    path = "/data/a file$(id);'[]#.^$"
    assert_equal ["dokku", "storage:create", "watergun-123", path], Shellwords.split(Dokku::Storage::CreateEntry.new(name: "watergun-123", path: path, chown: "heroku").cmd)
    assert_equal ["dokku", "storage:list-entries", "--scheduler", "docker-local", "--format", "json"], Shellwords.split(Dokku::Storage::ListEntriesCommand.new.cmd)
    entries = [{"name" => "legacy-retained", "host_path" => path}]
    assert_equal entries, Dokku::Storage::ListEntriesCommand.new.parse_output(0, entries.to_json)
  end

  test "native phase JSON retains actual entry identity and attachment attributes" do
    pair = {entry: {name: "legacy-abcd", host_path: "/data/old", scheduler: "docker-local"}, attachment: {entry_name: "legacy-abcd", container_path: "/app/data", phases: ["run"], process_type: "_default_"}}
    result = Dokku::Storage::ListCommand.new(app: "app", phase: "run").parse_output(0, [pair].to_json)
    assert_equal [{"entry_name" => "legacy-abcd", "host_path" => "/data/old", "container_path" => "/app/data", "phases" => ["run"], "process_type" => "_default_", "scheduler" => "docker-local"}], result
  end
end
