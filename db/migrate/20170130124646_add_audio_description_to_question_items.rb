class AddAudioDescriptionToQuestionItems < ActiveRecord::Migration[5.0]
  def change
  	add_column :question_items, :audio_description, :string
  end
end
