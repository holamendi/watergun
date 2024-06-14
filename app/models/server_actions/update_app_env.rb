module ServerActions
  class UpdateAppEnv < ServerAction
    SLUG = "apps.update_env"

    alias_method :app, :actionable

    store_attribute :payload, :dokku_app_id, :string
    store_attribute :payload, :env, :json

    validates :dokku_app_id, presence: true
    validates :env, presence: true

    delegate :env_configuration, to: :app

    before_validation on: :create do
      self.dokku_app_id ||= app.dokku_id
      self.env ||= env_configuration.variables
    end

    def perform
      set_dokku_app_config!
    end

    private

    def set_dokku_app_config
      Dokku::Config::Set.cal!(ssh, app: dokku_app_id, env:)
    end
  end
end
