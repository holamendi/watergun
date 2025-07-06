class AddLastVisitedProjectIdToUsers < ActiveRecord::Migration[7.2]
  def change
    add_reference :users, :last_visited_project, foreign_key: {to_table: :projects}
  end
end
