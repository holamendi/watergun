class RemoveUserReferenceOnApiTokens < ActiveRecord::Migration[7.1]
  def change
    remove_reference :api_tokens, :user, null: false, foreign_key: true
  end
end
