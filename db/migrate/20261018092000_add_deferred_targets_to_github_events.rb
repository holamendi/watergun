class AddDeferredTargetsToGithubEvents < ActiveRecord::Migration[8.1]
  def change
    # NULL means legacy/not yet routed. Never automatically replay legacy events.
    # [] means every snapshotted target has accepted work or was removed.
    add_column :github_events, :pending_app_ids, :jsonb
  end
end
