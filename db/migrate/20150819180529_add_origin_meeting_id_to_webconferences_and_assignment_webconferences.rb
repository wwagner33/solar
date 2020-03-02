class AddOriginMeetingIdToWebconferencesAndAssignmentWebconferences < ActiveRecord::Migration[5.0]
  def change
    add_column :assignment_webconferences, :origin_meeting_id, :string
    add_column :webconferences, :origin_meeting_id, :string
  end
end
