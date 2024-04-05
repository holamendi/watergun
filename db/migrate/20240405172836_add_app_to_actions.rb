class AddAppToActions < ActiveRecord::Migration[7.1]
  def change
    add_reference :actions, :app, foreign_key: true
  end
end
