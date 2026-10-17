require "test_helper"
require Rails.root.join("db/migrate/20261017000000_digest_api_tokens")

class ApiTokenMigrationTest < ActiveSupport::TestCase
  test "populated legacy cutover preserves secrets expiry flags and IDs without new scopes" do
    connection = ActiveRecord::Base.connection
    original = connection.schema_search_path
    schema = "token_migration_#{Process.pid}_#{SecureRandom.hex(4)}"
    connection.execute("CREATE SCHEMA #{schema}")
    connection.schema_search_path = schema
    connection.schema_cache.clear!
    connection.create_table(:accounts) { |t| t.string :name }
    connection.create_table(:users) { |t| t.string :name }
    connection.create_table(:api_tokens) do |t|
      t.integer :account_id, null: false
      t.string :token, null: false
      t.string :name
      t.boolean :read_only, default: false, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end
    connection.add_index :api_tokens, :token, unique: true
    connection.execute("INSERT INTO accounts(id, name) VALUES (1, 'preserved')")
    secret = "legacy.#{SecureRandom.hex(4)}"
    expiry = 1.day.from_now.change(usec: 0)
    # The setup row is plaintext by definition; do not log its SQL literal.
    ActiveRecord::Base.logger.silence do
      connection.execute("INSERT INTO api_tokens(id, account_id, token, name, read_only, expires_at, created_at, updated_at) VALUES (7, 1, #{connection.quote(secret)}, 'legacy', true, #{connection.quote(expiry)}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)")
    end
    DigestApiTokens.new.migrate(:up)
    connection.schema_cache.clear!
    ApiToken.reset_column_information
    token = ApiToken.authenticate(secret)
    assert token
    assert_equal 7, token.id
    assert token.read_only?
    assert_equal expiry, token.expires_at
    assert_equal ["apps:read"], token.scopes
    assert_nil token.user_id
    assert_nil token.token
    row = connection.select_one("SELECT * FROM api_tokens WHERE id = 7")
    assert_not row.key?("token")
    assert_not row.values.any? { |value| value.to_s.include?(secret) }
    assert_equal Digest::SHA256.hexdigest(secret), row.fetch("token_digest")
    travel_to expiry do
      assert_nil ApiToken.authenticate(secret)
    end
    assert_raises(ActiveRecord::IrreversibleMigration) { DigestApiTokens.new.down }
  ensure
    connection.schema_search_path = original
    connection.execute("DROP SCHEMA IF EXISTS #{schema} CASCADE")
    connection.schema_cache.clear!
    ApiToken.reset_column_information
  end
end
