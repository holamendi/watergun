class RemoveStatusFromApps < ActiveRecord::Migration[7.1]
  def change
    remove_column :apps, :status, :string
  end
end
