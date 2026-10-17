class AddPublicOperationAcceptanceToServerActionRuns < ActiveRecord::Migration[8.1]
  def change
    change_table :server_action_runs do |t|
      t.bigint :api_token_id
      t.string :request_id
      t.bigint :operation_app_id
      t.bigint :operation_deployment_id
      t.string :idempotency_digest
      t.string :request_fingerprint
      t.datetime :dispatch_pending_at
      t.datetime :remote_completed_at
      t.string :public_error_code
      t.boolean :outcome_uncertain, default: false, null: false
    end
    add_index :server_action_runs, [:account_id, :api_token_id, :idempotency_digest],
      unique: true, where: "idempotency_digest IS NOT NULL", name: "index_server_action_runs_on_idempotency"
    add_index :server_action_runs, :dispatch_pending_at
    add_index :server_action_runs, :operation_app_id
  end
end
