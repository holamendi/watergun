class RenameServerIdentitiesToSshKeys < ActiveRecord::Migration[7.1]
  def change
    rename_table :server_identities, :ssh_keys
  end
end
