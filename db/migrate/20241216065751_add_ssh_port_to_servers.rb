class AddSshPortToServers < ActiveRecord::Migration[8.1]
  def change
    add_column :servers, :ssh_port, :integer, default: 22
  end
end
