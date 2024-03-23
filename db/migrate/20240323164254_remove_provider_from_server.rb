class RemoveProviderFromServer < ActiveRecord::Migration[7.1]
  def change
    remove_column :servers, :provider, :string
    remove_column :servers, :dokku_token, :string
  end
end
