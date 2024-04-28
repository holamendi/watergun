class AddTimestampsToServiceLinks < ActiveRecord::Migration[7.1]
  def change
    add_column :service_links, :linked_at, :datetime
    add_column :service_links, :unlinked_at, :timestamp
  end
end
