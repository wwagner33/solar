class CommentFile < ActiveRecord::Base

  belongs_to :assignment_comment

  validates :attachment_file_name, :presence => true

  ################################
  # attachment files
  ################################

  has_attached_file :attachment,
    :path => ":rails_root/media/portfolio/comments/:id_:basename.:extension",
    :url => "/media/portfolio/comments/:id_:basename.:extension"

  validates_attachment_size :attachment, :less_than => 5.megabyte, :message => " "

  validates_attachment_content_type_in_black_list :attachment

end
