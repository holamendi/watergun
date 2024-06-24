class AddUniqueIsDefaultIndexOnDomains < ActiveRecord::Migration[7.1]
  def change
    add_index :domains, [:app_id, :is_default], unique: true, where: "discarded_at IS NULL AND is_default = true"
  end
end
