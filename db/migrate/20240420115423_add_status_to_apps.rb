class AddStatusToApps < ActiveRecord::Migration[7.1]
  def change
    add_column :apps, :status, :string
  end
end
