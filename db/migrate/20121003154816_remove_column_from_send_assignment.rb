class RemoveColumnFromSendAssignment < ActiveRecord::Migration[5.0]
  def up
  	remove_column :send_assignments, :comment
  end

  def down
  	add_column :send_assignments, :comment, :text
  end
end
