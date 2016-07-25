class AcademicAllocationUser < ActiveRecord::Base

  belongs_to :academic_allocation
  belongs_to :user
  belongs_to :group_assignment

  has_one :allocation_tag, through: :academic_allocation
  has_one :exam,           through: :academic_allocation, conditions: { academic_allocations: { academic_tool_type: 'Exam' }}
  has_one :assignment,     through: :academic_allocation, conditions: { academic_allocations: { academic_tool_type: 'Assignment' }}
  has_one :chat_room,      through: :academic_allocation, conditions: { academic_allocations: { academic_tool_type: 'ChatRoom' }}
  has_one :schedule_event, through: :academic_allocation, conditions: { academic_allocations: { academic_tool_type: 'ScheduleEvent' }}
  has_one :discussion,     through: :academic_allocation, conditions: { academic_allocations: { academic_tool_type: 'Discussion' }}

  has_many :exam_user_attempts, dependent: :destroy
  has_many :exam_responses, through: :exam_user_attempts
  has_many :question_items, through: :exam_responses
  has_many :questions     , through: :question_items

  has_many :assignment_comments
  has_many :assignment_files
  has_many :assignment_webconferences

  has_many :discussion_posts

  has_many :chat_messages

  validates :user_id, uniqueness: { scope: [:group_assignment_id, :academic_allocation_id] }
  validates :user_id, presence: true, if: 'group_assignment_id.nil?'
  validates :grade, numericality: { greater_than_or_equal_to: 0, smaller_than_or_equal_to: 10, allow_blank: true }, unless: 'grade.blank?'
  validates :working_hours, numericality: { greater_than_or_equal_to: 0,  only_integer: true, allow_blank: true }, unless: 'working_hours.blank?'
  validate :verify_wh, if: '!working_hours.blank?'
  validate :verify_grade, if: '!grade.blank?'
  validate :verify_offer, :verify_date, if: '(working_hours_changed? || grade_changed?)'
  validates :group_assignment_id, presence: true, if: Proc.new { |a| a.try(:assignment).try(:type_assignment) == Assignment_Type_Group }

  before_save :if_group_assignment_remove_user_id
  before_save :verify_profile

  before_destroy :delete_with_dependents

  attr_accessor :merge

  STATUS = {
    empty: 0,
    sent: 1,
    evaluated: 2,
    without_group: 3
  }

  # begin validations #

  def verify_wh
    if !academic_allocation.frequency
      errors.add(:working_hours, I18n.t('academic_allocation_users.errors.not_frequency')) 
    else
      errors.add(:working_hours, I18n.t('academic_allocation_users.errors.lower_than_max', max: academic_allocation.max_working_hours)) if working_hours > academic_allocation.max_working_hours
    end
  end

  def verify_grade
    unless academic_allocation.academic_tool_type == 'Exam'
        errors.add(:grade, I18n.t('academic_allocation_users.errors.not_evaluative')) if !academic_allocation.evaluative && academic_allocation.academic_tool_type != 'Assignment'
        errors.add(:grade, I18n.t('academic_allocation_users.errors.lower_than_10')) if grade > 10
    end
  end

  def verify_offer
    offer_active = allocation_tag.offers.first.is_active?
    
    errors.add(:grade, I18n.t('academic_allocation_users.errors.offer')) if academic_allocation.evaluative && grade_changed? && !offer_active
    errors.add(:working_hours, I18n.t('academic_allocation_users.errors.offer')) if academic_allocation.frequency && working_hours_changed? && !offer_active
  end

  def verify_date
    unless academic_allocation.academic_tool_type.constantize.find(academic_allocation.academic_tool_id).started?
      errors.add(:grade, I18n.t('academic_allocation_users.errors.opened')) if academic_allocation.evaluative && grade_changed?
      errors.add(:working_hours, I18n.t('academic_allocation_users.errors.opened')) if academic_allocation.frequency && working_hours_changed?
    end
  end

  # if not student, set evaluation as nil
  def verify_profile
    unless !group_assignment_id.nil? || user.has_profile_type_at(allocation_tag.related)
      self.grade = nil
      self.working_hours = nil
    end
  end

  # end validations #

  def if_group_assignment_remove_user_id
    self.user_id = nil if group_assignment_id
  end

  def get_user
    (user_id.blank? ? group_assignment.group_participants.map(&:user_id) : [user_id])
  end

  # call after every acu grade change
  def recalculate_final_grade(allocation_tag_id)
    get_user.compact.each do |user|
      allocations = Allocation.includes(:profile).where(user_id: user, status: Allocation_Activated, allocation_tag_id: AllocationTag.find(allocation_tag_id).lower_related).where('cast(profiles.types & ? as boolean)', Profile_Type_Student)
      allocation = allocations.where('final_grade IS NOT NULL').first || allocations.first

      allocation.calculate_final_grade
    end
  end

  def self.create_or_update(tool_type, tool_id, allocation_tag_id, user={user_id: nil, group_assignment_id: nil}, evaluation={grade: nil, working_hours: nil})
    ac = AcademicAllocation.where(academic_tool_id: tool_id, academic_tool_type: tool_type, allocation_tag_id: AllocationTag.find(allocation_tag_id).upper_related).first

    if user[:group_assignment_id].blank?
      user_id = user[:user_id]
    else
      group_id = user[:group_assignment_id].to_i
    end

    if !group_id.nil? || User.find(user_id).has_profile_type_at(allocation_tag_id)
      acu = AcademicAllocationUser.where(academic_allocation_id: ac.id, user_id: user_id, group_assignment_id: group_id).first_or_initialize

      tool_type.constantize.update_previous(ac.id, user_id, acu.id) if acu.new_record? && !user_id.nil?

      acu.grade = evaluation[:grade].blank? ? nil : evaluation[:grade].to_f
      acu.working_hours = evaluation[:working_hours].blank? ? nil : evaluation[:working_hours]

      if !acu.grade.blank? || !acu.working_hours.blank?
        acu.status = STATUS[:evaluated]
      else
        acu.status = tool_type.constantize.verify_previous(acu.id) ? STATUS[:sent] : STATUS[:empty]
      end

      if acu.save
        acu.recalculate_final_grade(ac.allocation_tag_id)
        return {id: acu.id, errors: []}
      else
        return {id: acu.try(:id), errors: acu.errors.full_messages}
      end
    else
      return {id: acu.try(:id), errors: [I18n.t('academic_allocation_users.errors.student_group')]}
    end
  end

  # must be called only when sending a activity
  def self.find_or_create_one(academic_allocation_id, allocation_tag_id, user_id, group_id=nil, new_object=false)
    if !group_id.nil? || User.find(user_id).has_profile_type_at(allocation_tag_id)
      acu = AcademicAllocationUser.where(academic_allocation_id: academic_allocation_id, user_id: (group_id.nil? ? user_id : nil), group_assignment_id: group_id).first_or_create 
      if acu.grade.blank? && acu.working_hours.blank?
        acu.update_attributes status: STATUS[:sent]
      else
        acu.update_attributes new_after_evaluation: new_object 
      end

      acu
    end
  end

  # must be called whenever wants to get acu without being studen accessing own activity
  def self.find_one(academic_allocation_id, user_id, group_id=nil, new_object=false)
    acu = AcademicAllocationUser.where(academic_allocation_id: academic_allocation_id, user_id: (group_id.nil? ? user_id : nil), group_assignment_id: group_id).first
    unless acu.blank?
      if (acu.grade.blank? && acu.working_hours.blank?)
        acu.update_attributes status: STATUS[:empty]
      else
        acu.update_attributes new_after_evaluation: new_object
      end
    end
    acu
  end 

  def self.set_new_after_evaluation(allocation_tag_id, tool_id, tool_type, users_ids, group_id=nil, new_object=false)
    AcademicAllocationUser.joins(:academic_allocation).where(academic_allocations: {academic_tool_id: tool_id, academic_tool_type: tool_type, allocation_tag_id: allocation_tag_id}, user_id: (group_id.nil? ? users_ids : nil), group_assignment_id: group_id).update_all new_after_evaluation: false
  end

  def self.get_grade_and_wh(user_id, tool, tool_id)
    acu = joins(:academic_allocation).where(academic_allocations: {academic_tool_id: tool_id, academic_tool_type: tool}, user_id: user_id).last
    {grade: acu.try(:grade), wh: acu.try(:working_hours)}
  end 

  def self.any_evaluated?(ats, tool_id=nil, tool_type=nil)
    query = { academic_allocations: {allocation_tag_id: ats} }
    query[:academic_allocations].merge!({ academic_tool_type: tool_type, academic_tool_id: tool_id }) unless tool_id.blank? && tool_type.blank?
    joins(:academic_allocation).where(query).where('grade IS NOT NULL OR working_hours IS NOT NULL').any?
  end

  # begin exam stuff #

  def copy_dependencies_from(acu)
    unless acu.exam_user_attempts.empty?
      acu.exam_user_attempts.each do |attempt|
        new_attempt = ExamUserAttempt.where(attempt.attributes.except('id').merge!({ academic_allocation_user_id: self.id })).first_or_create
        new_attempt.copy_dependencies_from(attempt)
      end
    end
  end

  def answered_questions(last_attempt=nil)
    last_attempt = exam_user_attempts.last if last_attempt.blank?
    return 0 if last_attempt.blank?
    Question.joins(question_items: [exam_responses: :exam_user_attempt]).where(exam_user_attempts: {id: last_attempt.id}).pluck(:id).uniq.count rescue 0
  end

  def has_attempt(exam)
    (exam_user_attempts.empty? || !exam_user_attempts.last.complete || (exam.attempts > exam_user_attempts.count))
  end

  def delete_with_dependents
    case academic_allocation.academic_tool_type
    when 'Exam'
      exam_user_attempts.map(&:delete_with_dependents)
      self.delete
    when 'Assignment'
      assignment_comments.map(&:delete_with_dependents)
      assignment_files.delete_all
      assignment_webconferences.map(&:remove_records) rescue nil
      assignment_webconferences.delete_all
      self.delete
    when 'ChatRoom'
      chat_messages.delete_all
      self.delete
    when 'Discussion'
      discussion_posts.map(&:delete_with_dependents)
      self.delete
    end
  end

  def count_attempts
    count = exam_user_attempts.where(complete: true).count
    count = 1 if count.zero?
    count
  end

  def find_or_create_exam_user_attempt
    exam_user_attempt_last = exam_user_attempts.last

    (exam_user_attempt_last.nil? || (exam_user_attempt_last.complete && exam_user_attempt_last.exam.attempts > exam_user_attempts.count)) ?  exam_user_attempts.create(academic_allocation_user_id: id, start: Time.now) : exam_user_attempt_last
  end

  def finish_attempt
    last_attempt = exam_user_attempts.last
    last_attempt.end = DateTime.now
    last_attempt.complete = true
    last_attempt.save

    self.update_attributes status: STATUS[:sent]
  end

  def status_exam
    last_attempt  = exam_user_attempts.last
    user_attempts = exam_user_attempts.count
    case
    when !exam.started?                                                      then 'not_started'
    when exam.on_going? && (exam_responses.blank? || exam_responses == 0)    then 'to_answer'
    when exam.on_going? && !last_attempt.complete                            then 'not_finished'
    when exam.on_going? && (exam.attempts > user_attempts)                   then 'retake'
    when !grade.blank? && exam.ended?                                        then 'corrected'
    when last_attempt.complete && (exam.attempts == user_attempts)           then 'finished'
    when exam.ended? && (user_attempts != 0 && !user_attempts.blank?) && grade.blank? then 'not_corrected'
    else
      'not_answered'
    end
  end

  # end exam stuff #

  def info
    case academic_allocation.academic_tool_type
    when 'Exam'
      complete_attempts = exam.ended? ? exam_user_attempts : exam_user_attempts.where(complete: true)
      last_attempt = exam_user_attempts.last

      { grade: self.grade, complete: last_attempt.try(:complete), attempts: exam_user_attempts.count, responses: answered_questions(last_attempt) }
    when 'Assignment' 
      grade, comments = try(:grade), try(:assignment_comments)
    
      files = AcademicAllocationUser.find_by_sql <<-SQL
        SELECT MAX(max_date) FROM (
          SELECT MAX(initial_time) AS max_date FROM assignment_webconferences 
          WHERE academic_allocation_user_id = #{id}
          AND is_recorded = 't'
          AND (initial_time + (interval '1 minutes')*duration) < now()

          UNION

          SELECT MAX(attachment_updated_at) AS max_date FROM assignment_files 
          WHERE attachment_updated_at IS NOT NULL 
          AND academic_allocation_user_id = #{id}
        ) AS max;

      SQL

      has_files = !files.first.max.nil?
      { grade: grade, comments: comments, has_files: has_files, file_sent_date: (has_files ? I18n.l(files.first.max.to_datetime, format: :normal) : ' - ') }
    end
  end

  # begin assignment stuff

  def users_count
    has_group ? group_assignment.group_participants.count : 1
  end

  # end assignment stuff

end