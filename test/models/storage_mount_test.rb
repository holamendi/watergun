require "test_helper"

class StorageMountTest < ActiveSupport::TestCase
  def setup
    @app = apps(:domain_test_app)
  end

  test "auto-generates host_path from container_path" do
    mount = @app.storage_mounts.create!(container_path: "/app/uploads")

    assert_equal "/var/lib/dokku/data/storage/domain-test-app/app_uploads", mount.host_path
  end

  test "auto-generates host_path with nested path" do
    mount = @app.storage_mounts.create!(container_path: "/data/files/uploads")

    assert_equal "/var/lib/dokku/data/storage/domain-test-app/data_files_uploads", mount.host_path
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
