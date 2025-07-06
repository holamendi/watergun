class AddBytesToContainersAndContainerMetrics < ActiveRecord::Migration[7.2]
  def change
    add_column :containers, :block_io_read_bytes, :integer
    add_column :containers, :block_io_write_bytes, :integer
    add_column :containers, :network_io_in_bytes, :integer
    add_column :containers, :network_io_out_bytes, :integer
    add_column :containers, :memory_used_bytes, :integer
    add_column :containers, :memory_limit_bytes, :integer
    remove_column :containers, :memory_usage, :string
    remove_column :containers, :cpu_usage, :string
    remove_column :containers, :block_io, :string
    remove_column :containers, :network_io, :string
    rename_column :containers, :last_synced_at, :checked_at

    add_column :container_checks, :block_io_read_bytes, :integer
    add_column :container_checks, :block_io_write_bytes, :integer
    add_column :container_checks, :network_io_in_bytes, :integer
    add_column :container_checks, :network_io_out_bytes, :integer
    add_column :container_checks, :memory_used_bytes, :integer
    add_column :container_checks, :memory_limit_bytes, :integer
    remove_column :container_checks, :memory_usage, :string
    remove_column :container_checks, :cpu_usage, :string
    remove_column :container_checks, :block_io, :string
    remove_column :container_checks, :network_io, :string
  end
end
