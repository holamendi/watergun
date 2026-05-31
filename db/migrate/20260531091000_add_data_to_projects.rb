class AddDataToProjects < ActiveRecord::Migration[8.2]
  def change
    add_column :projects, :data, :json, default: {}, null: false
  end
end
