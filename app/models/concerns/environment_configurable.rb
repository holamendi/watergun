module EnvironmentConfigurable
  extend ActiveSupport::Concern

  included do
    has_one :environment_configuration, as: :environment_configurable, dependent: :destroy

    after_create :create_environment_configuration
  end
end
