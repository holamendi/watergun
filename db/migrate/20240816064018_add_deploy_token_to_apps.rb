class AddDeployTokenToApps < ActiveRecord::Migration[7.2]
  def change
    add_column :apps, :deploy_token, :string
    add_index :apps, :deploy_token, unique: true

    App.find_each(&:regenerate_deploy_token)
  end
end
