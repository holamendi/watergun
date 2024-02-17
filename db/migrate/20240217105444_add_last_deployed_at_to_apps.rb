class AddLastDeployedAtToApps < ActiveRecord::Migration[7.1]
  def change
    add_column :apps, :last_deployed_at, :datetime
  end
end
