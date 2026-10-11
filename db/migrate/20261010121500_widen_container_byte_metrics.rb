class WidenContainerByteMetrics < ActiveRecord::Migration[8.1]
  def change
    %i[containers container_checks].each do |table|
      %i[block_io_read_bytes block_io_write_bytes memory_used_bytes memory_limit_bytes network_io_in_bytes network_io_out_bytes].each do |column|
        change_column table, column, :bigint
      end
    end
  end
end
