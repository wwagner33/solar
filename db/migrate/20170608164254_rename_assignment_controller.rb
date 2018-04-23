class RenameAssignmentController < ActiveRecord::Migration[5.0]
  def up
  	rename_column :assignments, :controller, :controlled
  end

  def down
  	rename_column :assignments, :controlled, :controller
  end
end
