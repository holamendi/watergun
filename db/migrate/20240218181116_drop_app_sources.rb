class DropAppSources < ActiveRecord::Migration[7.1]
  def change
    drop_table :app_sources
  end
end
