class ServerAction::UpdateBuilder < ServerAction
  SLUG = "apps.update_builder"

  actionable App

  store_attribute :payload, :dokku_app_id, :string
  store_attribute :payload, :builder, :string

  validates :dokku_app_id, presence: true

  before_validation on: :create do
    self.dokku_app_id ||= app.dokku_id
    self.builder ||= app.builder
  end

  private

  def run
    set_dokku_app_builder!
  end

  def set_dokku_app_builder!
    Dokku::Builder::Set.call!(ssh, app: dokku_app_id, builder:)
  end
end
