class AddColumnsToServer < ActiveRecord::Migration[7.1]
  def change
    add_column :servers, :public_ip, :string
    add_column :servers, :cpu_type, :string
    change_column_null :servers, :provider, false
  end
end
