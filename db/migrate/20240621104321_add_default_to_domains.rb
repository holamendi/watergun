class AddDefaultToDomains < ActiveRecord::Migration[7.1]
  def change
    add_column :domains, :is_default, :boolean, default: false, null: false
    add_index :domains, :is_default, unique: true, where: "is_default = true"
  end
end
