module EnvConfigurable
  extend ActiveSupport::Concern

  included do
    has_one :env_configuration, as: :env_configurable, dependent: :destroy

    after_create :create_env_configuration
  end
end
