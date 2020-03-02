class AddStatusToExam < ActiveRecord::Migration[5.0]
  def change
    add_column :exams, :status, :boolean, null: false, default: false
  end
end
