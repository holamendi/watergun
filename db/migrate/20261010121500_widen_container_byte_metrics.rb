class WidenContainerByteMetrics < ActiveRecord::Migration[8.1]
  TABLES = %i[containers container_checks]
  COLUMNS = %i[block_io_read_bytes block_io_write_bytes memory_used_bytes memory_limit_bytes network_io_in_bytes network_io_out_bytes]

  def up
    change_columns_type :bigint
  end

  def down
    change_columns_type :integer
  end

  private

  def change_columns_type(type)
    TABLES.each do |table|
      COLUMNS.each do |column|
        change_column table, column, type
      end
    end
  end
end
