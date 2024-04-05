class EnvironmentConfiguration < ApplicationRecord
  include BelongsToOrg

  attr_writer :variables_as_string

  belongs_to :environment_configurable, polymorphic: true

  after_update_commit -> { environment_configurable.enqueue_action!(:update_env, dokku_id:, environment_variables: variables) }, if: :saved_change_to_variables?

  delegate :dokku_id, to: :environment_configurable

  def variables=(value)
    if value.is_a?(String)
      super(Dotenv::Parser.call(value))
    else
      super(value)
    end
  end

  def variables_as_string
    variables.map { |k, v| "#{k}=#{v}" }.join("\n")
  end
end
