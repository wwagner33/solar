class ChangeAudioDescriptionInQuestionItems < ActiveRecord::Migration[5.0]
  def up
  	change_column :question_items, :audio_description, :text
  end

  def down
  	change_column :question_items, :audio_description, :string
  end
end
