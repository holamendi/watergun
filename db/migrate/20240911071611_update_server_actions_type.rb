class UpdateServerActionsType < ActiveRecord::Migration[8.0]
  def up
    execute <<-SQL
      UPDATE server_actions
      SET type = REPLACE(type, 'ServerAction', 'ServerActions::')
      WHERE type LIKE 'ServerAction::%'
    SQL
  end

  def down
    execute <<-SQL
      UPDATE server_actions
      SET type = REPLACE(type, 'ServerActions::', 'ServerAction')
      WHERE type LIKE 'ServerActions::%'
    SQL
  end
end
