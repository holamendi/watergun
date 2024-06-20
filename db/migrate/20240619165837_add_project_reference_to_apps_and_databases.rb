class AddProjectReferenceToAppsAndDatabases < ActiveRecord::Migration[7.1]
  def change
    add_reference :apps, :project, foreign_key: true
    add_reference :databases, :project, foreign_key: true
  end
end
