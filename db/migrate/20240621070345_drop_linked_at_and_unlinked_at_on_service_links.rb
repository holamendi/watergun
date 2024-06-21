class DropLinkedAtAndUnlinkedAtOnServiceLinks < ActiveRecord::Migration[7.1]
  def change
    remove_column :service_links, :linked_at, :datetime
    remove_column :service_links, :unlinked_at, :datetime
  end
end
