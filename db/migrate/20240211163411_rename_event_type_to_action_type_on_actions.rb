class RenameEventTypeToActionTypeOnActions < ActiveRecord::Migration[7.1]
  def change
    rename_column :actions, :event_type, :action_type
  end
end
