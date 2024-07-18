class AddUserToServerActions < ActiveRecord::Migration[7.2]
  def change
    add_reference :server_actions, :user, foreign_key: true
  end
end
