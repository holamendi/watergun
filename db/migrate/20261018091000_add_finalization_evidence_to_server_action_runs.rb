class AddFinalizationEvidenceToServerActionRuns < ActiveRecord::Migration[8.1]
  def change
    # NULL on historical rows is deliberately not proof that required local
    # finalization completed. Keep remote evidence and require inspection.
    add_column :server_action_runs, :finalized_at, :datetime
  end
end
