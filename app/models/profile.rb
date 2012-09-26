class Profile < ActiveRecord::Base

  has_many :allocations
  has_many :users, :through => :allocations
  has_many :permissions_resources
  has_many :permissions_menus

  ##
  # recupera uma lista perfis que possuem quaisquer permissões requisitadas
  ##
  def self.authorized_profiles(resources)

    query = <<SQL
      SELECT DISTINCT p.*
      from
        profiles p
        inner join permissions_resources r on p.id = r.profile_id
      where
        r.profile_id in (#{resources.join(',')})
SQL
    return self.find_by_sql(query)
  end

  def has_type?(type)
    (self.types & type) == type
  end
   
  def self.students_of_class(allocation_tag_id)
    allocations_of_class = Allocation.find_all_by_allocation_tag_id(allocation_tag_id)
    students_of_class = []
    for allocation in allocations_of_class
      students_of_class << User.find(allocation.user_id) if allocation.profile.has_type?(Profile_Type_Student)
    end
    return students_of_class
  end

  def self.user_allocation_tag_profile(allocation_tag_id, user_id)
    profile_name = Allocation.find_by_allocation_tag_id_and_user_id(allocation_tag_id, user_id).profile.name
    return (profile_name)
  end

  def self.student_from_class?(user_id, allocation_tag_id)
    students_of_class = Assignment.list_students_by_allocations(allocation_tag_id).map(&:id)
    return (students_of_class.include?(user_id))
  end

end