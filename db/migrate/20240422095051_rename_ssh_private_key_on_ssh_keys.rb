class RenameSshPrivateKeyOnSshKeys < ActiveRecord::Migration[7.1]
  def change
    rename_column :ssh_keys, :ssh_private_key, :private_key
  end
end
