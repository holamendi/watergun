class AddOrgIdToServer < ActiveRecord::Migration[7.1]
  def change
    add_reference :servers, :org, null: false, foreign_key: true
  end
end
