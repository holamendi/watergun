class AddDiscardedAtToServiceLinks < ActiveRecord::Migration[7.1]
  def change
    add_column :service_links, :discarded_at, :datetime
    add_index :service_links, :discarded_at
  end
end
