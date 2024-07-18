class AddUserToDeployments < ActiveRecord::Migration[7.2]
  def change
    add_reference :deployments, :user, foreign_key: true
  end
end
