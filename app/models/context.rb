class Context < ActiveRecord::Base

  has_many :menus_contexts
  has_many :menus, through: :menus_contexts

end
