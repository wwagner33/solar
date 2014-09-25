class Assignment < Event

  GROUP_PERMISSION = true

  belongs_to :schedule

  has_many :allocation_tags, through: :academic_allocations

  has_many :enunciation_files, class_name: "AssignmentEnunciationFile", dependent: :destroy
  has_many :assignment_enunciation_files, dependent: :destroy # deletar se nao existir mais chamadas para este

  has_many :allocations, through: :allocation_tags
  has_many :groups, through: :allocation_tags
  has_many :group_participants, through: :group_assignments # VERIFICAR

  #Associação polimórfica
  has_many :academic_allocations, as: :academic_tool, dependent: :destroy
  has_many :sent_assignments, through: :academic_allocations
  has_many :group_assignments, through: :academic_allocations
  #Associação polimórfica

  accepts_nested_attributes_for :schedule
  accepts_nested_attributes_for :enunciation_files, allow_destroy: true, reject_if: proc {|attributes| not attributes.include?(:attachment)}

  validates :name, :enunciation, :type_assignment, presence: true
  validates :name, length: {maximum: 1024}

  attr_accessible :schedule_attributes, :enunciation_files_attributes, :name, :enunciation, :type_assignment, :schedule_id

  def copy_dependencies_from(assignment_to_copy)
    AssignmentEnunciationFile.create! assignment_to_copy.enunciation_files.map {|file| file.attributes.merge({assignment_id: self.id})} unless assignment_to_copy.enunciation_files.empty?
    GroupAssignment.create! assignment_to_copy.group_assignments.map {|group| group.attributes.merge({academic_allocation_id: self.academic_allocations.first.id})} unless assignment_to_copy.group_assignments.empty?
  end

  def can_remove_or_unbind_group?(group)
    # não pode dar unbind nem remover se assignment possuir sent_assignment
    SentAssignment.joins(:academic_allocation).where(academic_allocations: {academic_tool_id: self.id, allocation_tag_id: group.allocation_tag.id}).empty?
  end

  def student_group_by_student(student_id, allocation_tag_id)
    (self.type_assignment == Assignment_Type_Group) ?
      (GroupAssignment.first(
      joins: :academic_allocation,
      include: :group_participants,
      conditions: ["group_participants.user_id = ? AND academic_allocations.academic_tool_id = ? AND allocation_tag_id = ?", student_id, self.id, allocation_tag_id])) : nil
  end

  def sent_assignment_by_user_id_or_group_assignment_id(allocation_tag_id, user_id, group_assignment_id)
    SentAssignment.joins(:academic_allocation).where(user_id: user_id, group_assignment_id: group_assignment_id, academic_allocations: {academic_tool_id: self.id, allocation_tag_id: allocation_tag_id}).first
  end   

  def closed?
    schedule.end_date.to_date < Date.today
  end

  def extra_time?(allocation_tag, user_id)
    extra = (allocation_tag.is_observer_or_responsible?(user_id) and closed?)

    return false unless extra

    offer = case allocation_tag.refer_to
    when 'offer'
      allocation_tag.offer
    when 'group'
      allocation_tag.group.offer
    end

    # periodo pode estar definido na oferta ou no semestre
    period_end_date = if offer.period_schedule.nil?
      offer.semester.offer_schedule.end_date
    else
      offer.period_schedule.end_date
    end

    extra and period_end_date.to_date >= Date.today

    # em fórum tá assim:
    # ((self.allocation_tags.map {|at| at.is_observer_or_responsible?(user_id)}).include?(true) and self.closed?) ?
    #   ((self.schedule.end_date.to_date + Discussion_Responsible_Extra_Time) >= Date.today) : false
  end

  ## Verifica período que o responsável pode alterar algo na atividade
  #  procurar por assignment_in_time?
  def in_time?(allocation_tag_id, user_id)
    (verify_date_range(schedule.start_date, schedule.end_date, Date.today) or extra_time?(AllocationTag.find(allocation_tag_id), user_id))
  end

  ## Verifica se uma data esta em um intervalo de outras
  def verify_date_range(start_date, end_date, date)
    (date >= start_date.to_date and date <= end_date.to_date)
  end

  ## Lista de alunos presentes nas turmas
  def self.list_students_by_allocations(allocations_ids)
    students_of_class_ids = Allocation.all(:include => [:allocation_tag, :user, :profile], :conditions => ["cast( profiles.types & '#{Profile_Type_Student}' as boolean) 
      AND allocations.status = #{Allocation_Activated} AND allocation_tags.group_id IS NOT NULL AND allocation_tags.id IN (#{allocations_ids})"]).map(&:user_id)
    students_of_class = User.select("name, id").find(students_of_class_ids)
    return students_of_class
  end

  def info(user_id, allocation_tag_id, group_id = nil)
    academic_allocation = AcademicAllocation.where(allocation_tag_id: allocation_tag_id, academic_tool_id: self.id, academic_tool_type: "Assignment").first
    sent_assignments    = academic_allocation.sent_assignments
    params = if self.type_assignment == Assignment_Type_Group
      group_id = GroupAssignment.joins(:group_participants).where(group_participants: {user_id: user_id}, group_assignments: {academic_allocation_id: academic_allocation.id}).first.try(:id) if group_id.nil?
      {group_assignment_id: group_id}
    else
      {user_id: user_id}
    end

    sent_assignment = sent_assignments.where(params).first
    grade, comments, files = sent_assignment.try(:grade), sent_assignment.try(:assignment_comments), sent_assignment.try(:assignment_files)
    has_files = (not(files.nil?) and files.any?)
    file_sent_date = (has_files ? I18n.l(files.first.attachment_updated_at, format: :normal) : " - ")
    {situation: self.situation(has_files, not(group_id.nil?), grade), grade: grade, has_comments: (not(comments.nil?) and comments.any?), has_files: has_files, group_id: group_id, file_sent_date: file_sent_date}
  end

  def situation(has_files, has_group, grade = nil)
    case
      when schedule.start_date.to_date > Date.current; "not_started"
      when not(grade.nil?); "corrected"
      when has_files; "sent"
      when (self.type_assignment == Assignment_Type_Group and not(has_group)); "without_group"
      when (schedule.end_date.to_date >= Date.today); "send"
      when (schedule.end_date.to_date < Date.today); "not_sent"
      else
        "-"
    end
  end

  def students_without_groups(allocation_tag)
    academic_allocation = AcademicAllocation.find_by_allocation_tag_id_and_academic_tool_id_and_academic_tool_type(allocation_tag.id, self.id, 'Assignment')
    students_in_class   = Assignment.list_students_by_allocations(allocation_tag.id).map(&:id)
    students_with_group = (academic_allocation.nil? ? [] : academic_allocation.group_assignments.map(&:group_participants).flatten.map(&:user_id))
    students            = [students_in_class - students_with_group].flatten.compact.uniq
    return students.empty? ? [] : User.select('id, name').find(students)
  end

end

