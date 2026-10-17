require "digest"

class DigestApiTokens < ActiveRecord::Migration[8.1]
  def up
    add_column :api_tokens, :token_digest, :string
    add_reference :api_tokens, :user, foreign_key: true
    add_column :api_tokens, :scopes, :jsonb, default: ["apps:read"], null: false
    add_column :api_tokens, :revoked_at, :datetime
    add_column :api_tokens, :last_used_at, :datetime

    # Use no application model/callbacks and never interpolate plaintext in SQL.
    # Legacy ownership cannot be inferred; authenticated secret holders can claim it.
    connection.select_all("SELECT id, token FROM api_tokens").each do |row|
      digest = Digest::SHA256.hexdigest(row.fetch("token"))
      binds = [
        ActiveRecord::Relation::QueryAttribute.new("token_digest", digest, ActiveRecord::Type::String.new),
        ActiveRecord::Relation::QueryAttribute.new("id", row.fetch("id"), ActiveRecord::Type::Integer.new)
      ]
      connection.exec_update("UPDATE api_tokens SET token_digest = $1 WHERE id = $2", "Digest legacy API token", binds)
    end
    change_column_null :api_tokens, :token_digest, false
    add_index :api_tokens, :token_digest, unique: true
    remove_column :api_tokens, :token
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Token secrets cannot be recovered from digests"
  end
end
