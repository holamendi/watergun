class StorageMount < ApplicationRecord
  include Discard::Model
  include ServerActionable

  belongs_to :account, default: -> { app.account }
  belongs_to :app, touch: true

  enum :status, Enum[:pending, :active, :deleting, :error], default: :pending

  validates :container_path, presence: true,
    uniqueness: {scope: :app_id, conditions: -> { undiscarded }},
    format: {with: /\A\//, message: "must be an absolute path"}

  delegate :project, :server, to: :app

  before_create :set_host_path
  before_create :set_chown

  after_update_commit do
    broadcast_replace_later_to [app, :storage_mounts], target: dom_id(self),
      partial: "projects/apps/storage_mounts/storage_mount", locals: {storage_mount: self}
  end

  after_destroy_commit do
    broadcast_remove_to [app, :storage_mounts], target: dom_id(self)
  end

  private

  def set_host_path
    sanitized = container_path.delete_prefix("/").tr("/", "_")
    self.host_path = "/var/lib/dokku/data/storage/#{app.dokku_id}/#{sanitized}"
  end

  def set_chown
    self.chown = case app.builder
    when "herokuish" then "herokuish"
    when "nixpacks" then "heroku"
    end
  end
end
