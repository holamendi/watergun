class Api::ApiTokenResource < Api::ApplicationResource
  root_key :api_token, :api_tokens

  attributes :id, :name, :scopes, :read_only

  attribute :created_at do |token|
    token.created_at&.utc&.iso8601
  end

  attribute :expires_at do |token|
    token.expires_at&.utc&.iso8601
  end

  attribute :revoked_at do |token|
    token.revoked_at&.utc&.iso8601
  end

  attribute :last_used_at do |token|
    token.last_used_at&.utc&.iso8601
  end
end
