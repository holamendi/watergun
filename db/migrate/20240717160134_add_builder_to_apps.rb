class AddBuilderToApps < ActiveRecord::Migration[7.2]
  def change
    add_column :apps, :builder, :string
  end
end
