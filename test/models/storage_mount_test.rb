require "test_helper"

class StorageMountTest < ActiveSupport::TestCase
  def setup
    @app = apps(:domain_test_app)
  end

  test "unchanged legacy paths allow status transitions and recovery without moving data" do
    ["/app/uploads/", "/app/a file$(id);'[]#.^$"].each_with_index do |path, index|
      mount = @app.storage_mounts.create!(container_path: "/app/legacy_#{index}", status: :active)
      mount.update_columns(container_path: path, host_path: "/var/lib/dokku/data/storage/legacy_#{index}")
      original = [mount.host_path, mount.container_path]
      mount.error!
      assert mount.resume
      assert_equal "pending", mount.reload.status
      mount.server_actions.update_all(status: :failure)
      mount.active!
      assert StorageMount::DestroyStorageMount.new(mount).destroy
      mount.server_actions.update_all(status: :failure)
      mount.detach_failed!
      assert mount.resume
      mount.detached!
      assert_equal original, [mount.reload.host_path, mount.container_path]
      mount.container_path = "/changed/"
      assert_not mount.valid?
    end
  end

  test "rejects unsafe or non normalized container paths" do
    ["/", "/app/../data", "/app/./data", "/app//data", "/data/", "/data;whoami", "/data:ro", "/data\nother"].each do |path|
      assert_not @app.storage_mounts.new(container_path: path).valid?, path
    end
  end

  test "backing directory is unique stable and a direct Dokku storage child" do
    first = @app.storage_mounts.create!(container_path: "/app/uploads")
    second = @app.storage_mounts.create!(container_path: "/app_uploads")
    assert_match %r{\A/var/lib/dokku/data/storage/watergun-[a-f0-9]{32}\z}, first.host_path
    assert_not_equal first.host_path, second.host_path
    path = first.host_path
    first.update!(status: :error)
    assert_equal path, first.reload.host_path
  end

  test "auto-generates host_path with nested path" do
    mount = @app.storage_mounts.create!(container_path: "/data/files/uploads")

    assert_match %r{\A/var/lib/dokku/data/storage/watergun-[a-f0-9]{32}\z}, mount.host_path
  end

  test "sets chown to herokuish for herokuish builder" do
    @app.update!(builder: :herokuish)
    mount = @app.storage_mounts.create!(container_path: "/app/data")

    assert_equal "herokuish", mount.chown
  end

  test "sets chown to heroku for nixpacks builder" do
    @app.update!(builder: :nixpacks)
    mount = @app.storage_mounts.create!(container_path: "/app/data")

    assert_equal "heroku", mount.chown
  end

  test "allows explicit supported ownership for Dockerfile containers" do
    @app.update!(builder: :dockerfile)
    mount = @app.storage_mounts.create!(container_path: "/app/data", chown: "heroku")
    assert_equal "heroku", mount.chown
    assert_not @app.storage_mounts.new(container_path: "/other", chown: "1001:1001;id").valid?
    assert_not @app.storage_mounts.new(container_path: "/other", chown: "1001:1001").valid?
  end

  test "sets chown to nil for dockerfile builder" do
    @app.update!(builder: :dockerfile)
    mount = @app.storage_mounts.create!(container_path: "/app/data")

    assert_nil mount.chown
  end

  test "validates container_path is absolute" do
    mount = @app.storage_mounts.new(container_path: "relative/path")

    assert_not mount.valid?
    assert_includes mount.errors[:container_path], "must be an absolute path"
  end

  test "validates container_path presence" do
    mount = @app.storage_mounts.new(container_path: "")

    assert_not mount.valid?
    assert_includes mount.errors[:container_path], "can't be blank"
  end

  test "validates uniqueness of container_path per app" do
    @app.storage_mounts.create!(container_path: "/app/uploads")
    duplicate = @app.storage_mounts.new(container_path: "/app/uploads")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:container_path], "has already been taken"
  end

  test "allows same container_path on different apps" do
    other_app = apps(:smol_roda)
    @app.storage_mounts.create!(container_path: "/app/uploads")
    mount = other_app.storage_mounts.new(container_path: "/app/uploads")

    assert mount.valid?
  end
end
