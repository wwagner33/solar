class ExamUser < ActiveRecord::Base

  belongs_to :user
  belongs_to :academic_allocation, conditions: { academic_tool_type: 'Exam' }

  has_one :exam,     through: :academic_allocation
  has_one :allocation_tag, through: :academic_allocation

  has_many :exam_user_attempts, dependent: :destroy
  has_many :exam_responses, through: :exam_user_attempts
  has_many :question_items, through: :exam_responses
  has_many :questions     , through: :question_items

  attr_accessor :merge

  def answered_questions(last_attempt=nil)
    last_attempt = exam_user_attempts.last if last_attempt.blank?
    return 0 if last_attempt.blank?
    Question.joins(question_items: [exam_responses: :exam_user_attempt]).where(exam_user_attempts: {id: last_attempt.id}).pluck(:id).uniq.count rescue 0
  end

  def info
    complete_attempts = exam.ended? ? exam_user_attempts : exam_user_attempts.where(complete: true)
     
    last_attempt = exam_user_attempts.last
    grade = case exam.attempts_correction
            when Exam::GREATER; complete_attempts.map(&:grade).max
            when Exam::AVERAGE then 
              grades = complete_attempts.map(&:grade).compact
              grades.blank? ? nil : grades.inject{ |sum, el| sum + el }.to_f / grades.size
            when Exam::LAST; complete_attempts.last.grade
            end

    { grade: grade, complete: last_attempt.try(:complete), attempts: exam_user_attempts.count, responses: answered_questions(last_attempt) }
  end

  def has_attempt(exam)
    ((exam.attempts > exam_user_attempts.count) || (!exam_user_attempts.last.complete?))
  end

  def delete_with_dependents
    exam_user_attempts.map(&:delete_with_dependents)
    self.delete
  end

end
