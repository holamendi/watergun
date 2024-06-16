class DropUrlsOnApps < ActiveRecord::Migration[7.1]
  def change
    remove_column :apps, :urls, :json
  end
end
