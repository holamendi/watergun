class EnvConfiguration < ApplicationRecord
  belongs_to :org, default: -> { Current.org }

  attr_writer :variables_as_string

  belongs_to :env_configurable, polymorphic: true

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
