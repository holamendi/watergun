class AddDokkuIdToServices < ActiveRecord::Migration[7.1]
  def change
    add_column :services, :dokku_id, :string
  end
end
