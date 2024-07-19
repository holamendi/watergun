class LogStream < ApplicationRecord
  belongs_to :account, default: -> { Current.account }
  belongs_to :server, default: -> { Current.server }
  belongs_to :log_streamable, polymorphic: true

  attribute :uuid, :string, default: -> { SecureRandom.uuid }
end
