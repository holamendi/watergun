class DropFirstSignupTokenOnAccounts < ActiveRecord::Migration[7.2]
  def change
    remove_column :accounts, :first_signup_token, :string
  end
end
