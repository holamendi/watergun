class RenameDokkuUsersToServerIdentity < ActiveRecord::Migration[7.1]
  def change
    rename_table :dokku_users, :server_identities
  end
end
