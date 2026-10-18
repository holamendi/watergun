class AddEnvironmentIntentToApps < ActiveRecord::Migration[8.1]
  def change
    # Historical/imported rows have no provable ownership. Only explicit writes
    # claim a key; observations never do. The app counter invalidates old exports.
    add_column :env_variables, :managed, :boolean, default: false, null: false
    add_column :apps, :env_generation, :bigint, default: 0, null: false
  end
end
