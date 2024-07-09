class AddFirstSignupTokenToAccounts < ActiveRecord::Migration[7.2]
  def change
    add_column :accounts, :first_signup_token, :string
  end
end
