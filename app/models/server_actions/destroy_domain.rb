class ServerActions::DestroyDomain < ServerAction
  SLUG = "apps.remove_domain"

  actionable Domain

  store_attribute :payload, :dokku_app_id, :string
  store_attribute :payload, :hostname, :string

  validates :dokku_app_id, presence: true
  validates :hostname, presence: true

  before_validation on: :create do
    self.dokku_app_id ||= domain.app.dokku_id
    self.hostname ||= domain.hostname
  end

  def concurrency_key
    domain.app
  end

  def run
    domain.deleting!
    remove_dokku_domain!
  rescue Ssh::CommandExecutionError
    domain.error!
    raise
  else
    domain.destroy!
  end

  private

  def remove_dokku_domain!
    Dokku::Domains::Remove.call!(ssh, app: dokku_app_id, domain: hostname)
  end
end
