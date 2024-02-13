class AddPayloadToActions < ActiveRecord::Migration[7.1]
  def change
    add_column :actions, :payload, :json, null: false, default: {}
  end
end
