class RemoveThemeFromUsers < ActiveRecord::Migration[8.2]
  def change
    remove_column :users, :theme, :string
  end
end
