class AddFailureMessageToServerActions < ActiveRecord::Migration[7.1]
  def change
    add_column :server_actions, :failure_message, :string
  end
end
