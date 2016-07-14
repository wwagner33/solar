class AcademicAllocationUser < ActiveRecord::Base

  belongs_to :academic_allocation
  belongs_to :user
  belongs_to :group_assignment
	belongs_to :discussion_post

  has_one :allocation_tag, through: :academic_allocation

  validates :user_id, uniqueness: { scope: [:group_assignment_id, :academic_allocation_id] }

  validates :user_id, presence: true, if: 'group_assignment_id.nil?'

  before_save :if_group_assignment_remove_user_id

  def if_group_assignment_remove_user_id
    self.user_id = nil if group_assignment_id
  end

  def users_count
    has_group ? group_assignment.group_participants.count : 1
  end

  def get_user
    (user_id.nil? ? group_assignment.group_participants.map(&:user_id) : [user_id])
  end

  # call after every acu grade change
  def recalculate_final_grade(allocation_tag_id)
    get_user.compact.each do |user|
      allocations = Allocation.includes(:profile).where(user_id: user, status: Allocation_Activated, allocation_tag_id: allocation_tag_id).where('cast(profiles.types & ? as boolean)', Profile_Type_Student)
      allocation = allocations.where('final_grade IS NOT NULL').first || allocations.first

      allocation.calculate_final_grade
    end
  end

  def self.get_or_create_academic_allocation_user(tool, tool_id, user_id, academic_allocation, group_assignment_id=nil)
    allu = AcademicAllocationUser.joins('LEFT JOIN academic_allocations ON academic_allocations.id=academic_allocation_users.academic_allocation_id')
       .where('academic_allocation_users.user_id= ? AND academic_tool_type= ? AND academic_tool_id= ? ', user_id, tool, tool_id)
       .select("DISTINCT academic_allocation_users.id")

  	if allu.blank? #cria um novo
  		@academic_allocation_user = AcademicAllocationUser.create(academic_allocation_id: academic_allocation.id, user_id: user_id, group_assignment_id: group_assignment_id, grade: 0, status: 0)
  		id = @academic_allocation_user.id
  	else
  		id = allu.last.id
  		alluser = AcademicAllocationUser.find(id)
  		if alluser.grade > 0
  			alluser.new_after_evaluation = true
  			alluser.save
  		end	
  	end
  	id	
  end  

  def update_grade_and_frequency(grade, frequency)
  	max_working_hours = AcademicAllocation.find(self.academic_allocation_id).max_working_hours
  	g = grade>10 ? 10.00 : grade
    f = frequency>max_working_hours ? max_working_hours : frequency
  	self.grade = g
  	self.working_hours = f
  	self.new_after_evaluation = true
    self.save
  end

  def self.get_grade_alls_user(user_id, tool, tool_id)
    
    allu = AcademicAllocationUser.joins('LEFT JOIN academic_allocations ON academic_allocations.id=academic_allocation_users.academic_allocation_id')
      .where('academic_allocation_users.user_id= ? AND academic_tool_type= ? AND academic_tool_id= ? ', user_id, tool, tool_id).last
    grade = allu.blank? ? '' :  allu.grade
  end 

  def self.get_academic_allocation_user(tool_ac_al_user, tool, user_id, academic_tool, allocation_tag_id, model)
    if tool_ac_al_user.academic_allocation_user_id.blank?
      allocation_tag_ids  = AllocationTag.find(allocation_tag_id).related
      academic_allocation = academic_tool.academic_allocations.where(allocation_tag_id: allocation_tag_ids).first
      aau_id = AcademicAllocationUser.get_or_create_academic_allocation_user(tool, academic_tool.id, user_id, academic_allocation)
      @aalluser = AcademicAllocationUser.find(aau_id)
      AcademicAllocationUser.update_tools_academic_allocation_user(aau_id, allocation_tag_ids, academic_tool.id, tool, user_id, model, allocation_tag_id)
    else
      @aalluser = AcademicAllocationUser.find(tool_ac_al_user.academic_allocation_user_id)
    end  
    @aalluser.recalculate_final_grade(allocation_tag_id)
    @aalluser
  end 

  def self.update_tools_academic_allocation_user(aau_id, allocation_tags, academic_tool_id, tool, user_id, model, allocation_tag_id)
    tools_list = model.joins(:academic_allocation).where(academic_allocations: { allocation_tag_id: allocation_tags, academic_tool_id: academic_tool_id, academic_tool_type: tool }, user_id: user_id)
    .update_all(academic_allocation_user_id: aau_id) 
    
  end 

end
