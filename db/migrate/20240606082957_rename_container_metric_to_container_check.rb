class RenameContainerMetricToContainerCheck < ActiveRecord::Migration[7.1]
  def change
    rename_table :container_metrics, :container_checks
  end
end
