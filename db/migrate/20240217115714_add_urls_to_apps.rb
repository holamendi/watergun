class AddUrlsToApps < ActiveRecord::Migration[7.1]
  def change
    add_column :apps, :urls, :json, default: []
  end
end
