class CreateDeployments < ActiveRecord::Migration[7.1]
  def change
    create_table :deployments do |t|
      t.references :org, null: false, foreign_key: true
      t.references :app, null: false, foreign_key: true
      t.string :source, null: false
      t.string :status, null: false
      t.string :repo, null: false
      t.string :branch, null: false
      t.string :rev
      t.timestamp :finished_at

      t.timestamps
    end
  end
end
