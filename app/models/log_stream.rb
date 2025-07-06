class LogStream < ApplicationRecord
  belongs_to :account, default: -> { log_streamable.account }
  belongs_to :server, default: -> { log_streamable.server }
  belongs_to :log_streamable, polymorphic: true

  attribute :uuid, :string, default: -> { SecureRandom.uuid }
  attribute :last_ping_at, :datetime, default: -> { Time.current }

  def streaming?
    streaming_at.present?
  end
end
