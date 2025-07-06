class AddNameToApiTokens < ActiveRecord::Migration[7.2]
  def change
    add_column :api_tokens, :name, :string
  end
end
