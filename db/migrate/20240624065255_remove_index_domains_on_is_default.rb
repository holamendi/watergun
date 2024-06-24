class RemoveIndexDomainsOnIsDefault < ActiveRecord::Migration[7.1]
  def change
    remove_index :domains, :is_default
  end
end
