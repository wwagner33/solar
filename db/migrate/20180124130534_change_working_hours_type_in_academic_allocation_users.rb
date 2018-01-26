class ChangeWorkingHoursTypeInAcademicAllocationUsers < ActiveRecord::Migration
  def up
    change_column :academic_allocation_users, :working_hours, :decimal, :precision => 5, :scale => 2
  end

  def down
    change_column :academic_allocation_users, :working_hours, :integer
  end
end