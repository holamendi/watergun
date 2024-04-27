class RemoveMembershipIdFromServerActions < ActiveRecord::Migration[7.1]
  def change
    remove_column :server_actions, :membership_id, :bigint
  end
end
