class AddFirstRunCompletedAtToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :first_run_completed_at, :datetime
  end
end
