class ChangeAppStatusType < ActiveRecord::Migration[7.1]
  def change
    change_column :apps, :status, :integer
  end
end
