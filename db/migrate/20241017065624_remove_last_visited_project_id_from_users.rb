class RemoveLastVisitedProjectIdFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :last_visited_project_id
  end
end
