class AddStreamingAtToLogStreams < ActiveRecord::Migration[7.2]
  def change
    add_column :log_streams, :streaming_at, :datetime
  end
end
