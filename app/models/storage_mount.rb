class StorageMount < ApplicationRecord
  include Discard::Model
  include ServerActionable

  belongs_to :account, default: -> { app.account }
  belongs_to :app, touch: true

  enum :status, Enum[:pending, :active, :deleting, :error, :detaching, :detached, :detach_failed], default: :pending

  validates :container_path, presence: true,
    uniqueness: {scope: :app_id, conditions: -> { undiscarded }},
    format: {with: /\A\//, message: "must be an absolute path"}

  validates :chown, inclusion: {in: %w[herokuish heroku paketo false]}, allow_blank: true
  validate :safe_container_path, if: :will_save_change_to_container_path?

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

  def save_and_mount
    self.class.transaction do
      if save
        ServerActions::MountStorage.run_later!(server, self)
        true
      else
        false
      end
    end
  end

  def resume
    with_lock do
      return false unless detached? || error? || detach_failed?
      return false if server_actions.queued_or_running.exists?

      action_class = detach_failed? ? ServerActions::UnmountStorage : ServerActions::MountStorage
      update!(status: detach_failed? ? :detaching : :pending)
      action_class.run_later!(server, self)
    end
    true
  end

  private

  def safe_container_path
    return if container_path.blank?
    segments = container_path.split("/", -1).drop(1)
    unless container_path.match?(%r{\A/[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*\z}) && segments.none? { |segment| [".", ".."].include?(segment) }
      errors.add(:container_path, "must be a normalized absolute non-root path using letters, numbers, dots, underscores or hyphens")
    end
  end

  def set_host_path
    self.host_path = "/var/lib/dokku/data/storage/watergun-#{SecureRandom.hex(16)}"
  end

  def set_chown
    return if chown.present?

    self.chown = case app.builder
    when "herokuish" then "herokuish"
    when "nixpacks" then "heroku"
    end
  end
end
