class RemoveUniquePrivateKeyIndexFromDokkuUsers < ActiveRecord::Migration[7.1]
  def change
    remove_index :dokku_users, name: "index_dokku_users_on_private_key"
  end
end
