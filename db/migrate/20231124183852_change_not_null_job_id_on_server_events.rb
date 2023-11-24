class ChangeNotNullJobIdOnServerEvents < ActiveRecord::Migration[7.1]
  def change
    change_column_null :server_events, :job_id, true
  end
end
