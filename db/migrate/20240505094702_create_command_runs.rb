class CreateCommandRuns < ActiveRecord::Migration[7.1]
  def change
    create_table :command_runs do |t|
      t.references :org, null: false, foreign_key: true
      t.references :app, null: false, foreign_key: true
      t.string :command

      t.timestamps
    end
  end
end
