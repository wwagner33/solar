class ExamsController < ApplicationController

  include SysLog::Actions

  before_filter :prepare_for_group_selection, only: :index
  before_filter :get_groups_by_allocation_tags, only: [:new, :create]
  before_filter :verify_exam, only: [:open]
  layout false, except: :index

  def index
    @allocation_tag_id = active_tab[:url][:allocation_tag_id]
    authorize! :index, Exam, on: [@allocation_tag_id]
    @allocation_tags_ids = AllocationTag.find(@allocation_tag_id).related
    @exams = Exam.my_exams(@allocation_tags_ids)
  rescue
    render json: { success: false, alert: t(:no_permission) }, status: :unauthorized
  end

  def new
    @allocation_tags_ids = params[:allocation_tags_ids]
    @exam = Exam.new
    @exam.build_schedule(start_date: Date.today, end_date: Date.today)
  end

  def create
    authorize! :create, Exam, on: @allocation_tags_ids = params[:allocation_tags_ids]
    @exam = Exam.new exam_params
    @exam.allocation_tag_ids_associations = @allocation_tags_ids.split(' ').flatten
    @exam.schedule.verify_today = true

    if @exam.save
      render_exam_success_json('created')
    else
      render :new
    end
  rescue => error
    render_json_error(error, 'exams.error')
  end

  def list_exams_student
    authorize! :list_exams_student, Exam, on: [@allocation_tag_id = active_tab[:url][:allocation_tag_id]]
     @user = User.find(params[:student_id])
     @list_exam = Score.list_exams_stud(@user.id, @allocation_tag_id)
     respond_to do |format|
      format.html
      format.js
    end
  rescue CanCan::AccessDenied
    render json: { success: false, alert: t(:no_permission) }, status: :unauthorized
  rescue => error
    render_json_error(error, 'exams.error')
  end 

  # require 'will_paginate/array'
  def list
    @allocation_tags_ids = params[:groups_by_offer_id].present? ? AllocationTag.at_groups_by_offer_id(params[:groups_by_offer_id]) : params[:allocation_tags_ids]
    authorize! :list, Exam, { on: @allocation_tags_ids }

    @all_groups = Group.where(offer_id: params[:offer_id])
    @exams = Exam.exams_by_ats(@allocation_tags_ids.split(' '))#.paginate(page: params[:page], per_page: 1)
    @can_see_preview = can? :show, Question, { on: @allocation_tags_ids }
    respond_to do |format|
      format.html
      format.js
    end
  rescue CanCan::AccessDenied
    render json: { success: false, alert: t(:no_permission) }, status: :unauthorized
  rescue => error
    render_json_error(error, 'exams.error')
  end

  def edit
    @exam = Exam.find(params[:id])
  end

  def update
    @exam = Exam.find(params[:id])
    authorize! :update, Exam, { on: @exam.academic_allocations.pluck(:allocation_tag_id) }
    @exam.schedule.verify_today = true
    if @exam.update_attributes(exam_params)
      render_exam_success_json('updated')
    else
      render :edit
    end
  rescue CanCan::AccessDenied
    render json: { success: false, alert: t(:no_permission) }, status: :unauthorized
  rescue => error
    render_json_error(error, 'exams.error')
  end

  def destroy
    authorize! :destroy, Exam, { on: params[:allocation_tags_ids] }
    Exam.find(params[:id]).destroy
    render_exam_success_json('deleted')
  rescue CanCan::AccessDenied
    render json: { success: false, alert: t(:no_permission) }, status: :unauthorized
  rescue => error
    render_json_error(error, 'exams.error')
  end

  def pre
    #authorize! :open, Exam, { on: params[:allocation_tag_id] }
    @exam = Exam.find(params[:id])
    @allocation_tag_id = params[:allocation_tag_id]
    @situation =  params[:situation]

    @exam_user_id = Exam.find_or_create_exam_user(@exam, current_user.id, @allocation_tag_id)
    @total_attempts  = ExamUserAttempt.get_total_attempts(@exam_user_id)
    last_attempt = ExamUserAttempt.last_attempt(@exam_user_id)
    @total_time = (last_attempt.try(:complete?) ? 0 : last_attempt.try(:get_total_time)) || 0
    @open_button = @exam.on_going? && @exam_user_id.has_attempt(@exam)

    if (last_attempt.try(:uninterrupted_or_ended, @exam))
      @total_time = 0
      @exam.recalculate_grades(current_user.id, nil, true) if ExamUserAttempt.finish_attempt(@exam, @exam_user_id)
    end
    render :pre
  end

  def open
    authorize! :open, Exam, { on: params[:allocation_tag_id] }
    @situation =  params[:situation]
    @exam = Exam.find(params[:id])
    user_session[:blocking_content] = Exam.verify_blocking_content(current_user.id)
    @preview = false
    @disabled = false
    @exam_user_attempt_id = params[:exam_user_attempt_id]
    @allocation_tag_id = params[:allocation_tag_id]

    @exam_user_id = Exam.find_or_create_exam_user(@exam, current_user.id, @allocation_tag_id)
    @last_attempt = Exam.find_or_create_exam_user_attempt(@exam_user_id)
    @exam_questions = ExamQuestion.list(@exam.id, @exam.raffle_order, @last_attempt).paginate(page: params[:page], per_page: 1, total_entries: @exam.number_questions) unless @exam.nil?
    @total_time = (@last_attempt.try(:complete?) ? 0 : @last_attempt.try(:get_total_time)) || 0
    mod_correct_exam = @exam.attempts_correction

    if (@situation=='finished' || @situation=='corrected')
      @disabled = true
      @preview = true

      @exam_questions = ExamQuestion.list_correction(@exam.id, @exam.raffle_order).paginate(page: params[:page], per_page: 1, total_entries: @exam.number_questions) unless @exam.nil?
      if(mod_correct_exam != 1)
        @exam_user_attempt_id = Exam.get_id_exam_user_attempt(mod_correct_exam, @exam_user_id)
      end  

      @list_eua = ExamUserAttempt.where(exam_user_id: @exam_user_id)
      if mod_correct_exam == 1 && !params[:exam_user_attempt_id]  && params[:pdf].to_i != 1  
        render :open_result 
      else  
        @last_attempt = @exam.responses_question_user(@exam_user_id.id, params[:exam_user_attempt_id]) 
        if params[:pdf].to_i == 1
          @grade_pdf = ExamUserAttempt.find(@exam_user_attempt_id).grade
          @ats = AllocationTag.find(@allocation_tag_id)
          @exam_questions = ExamQuestion.list_correction(@exam.id, @exam.raffle_order) unless @exam.nil?
          @pdf = 1
          render :result_exam
        else  
         render :open 
        end
      end 
    else  
      respond_to do |format|
        format.html
        format.js
      end
    end
  rescue CanCan::AccessDenied
    render text: t(:no_permission)
  end

  def result_exam_user
    authorize! :open, Exam, { on: @allocation_tag_id = active_tab[:url][:allocation_tag_id] }
    @exam = Exam.find(params[:id])
    raise 'dates' unless @exam.ended?
    exam_user = ExamUser.joins(:academic_allocation).where(user_id: current_user.id, academic_allocations: { academic_tool_id: @exam.id, academic_tool_type: 'Exam', allocation_tag_id: AllocationTag.find(@allocation_tag_id).related }).first
    raise 'empty' if exam_user.nil?

    # get_grade tem que calcular a nota caso todas as tentativas n tenham e definir o resultado final em exam_user
    @grade = @exam.get_grade(exam_user.id)
    raise 'grade' if exam_user.grade.blank?

    @attempts = exam_user.exam_user_attempts
    @scores_exam = @exam.exam_questions.where(use_question: true).sum(:score)
    @scores_exam = @scores_exam > 10 ? 10.00 : @scores_exam
  rescue CanCan::AccessDenied
    render text: t(:no_permission)
  rescue => error
    render text: (I18n.translate!("exams.error.#{error}", raise: true) rescue t("exams.error.general_message"))
  end

  def complete
    exam = Exam.find(params[:id])

    @allocation_tag_id = active_tab[:url][:allocation_tag_id]
    exam_user_id = Exam.find_or_create_exam_user(exam, current_user.id, @allocation_tag_id)

    if (ExamUserAttempt.finish_attempt(exam, exam_user_id))
      user_session[:blocking_content] = false
      if (params[:error])
        respond_to do |format|
          format.js { render :js => "validation_error('#{I18n.t('exam_responses.error.' + params[:error] + '')}');" }
        end
      else
        render_exam_success_json('finish')
      end
    end
  rescue => error
    render_json_error(error, 'exams.error')
  end

  def calcule_grade_user
    exam = Exam.find(params[:id])
    grade = exam.recalculate_grades(current_user.id, nil, true)
    render json: { success: true, grade: grade, status: t('exams.situation.corrected'), notice: t('finish', scope: 'exams.success') }
  end 

  def calcule_grade
    #authorize! :finish, { on: params[:allocation_tag_id] }
    allocation_tags_ids = params[:allocation_tags_ids]
    ats = allocation_tags_ids.gsub(' ', ",")

    exam = Exam.find(params[:id])
    exam.recalculate_grades(nil, ats, true)
    render json: { success: true, notice: t('calcule_grade', scope: 'exams.list') }
  end  

  def change_status
    authorize! :change_status, Exam, { on: params[:allocation_tags_ids] }
    exam = Exam.find(params[:id])
    exam.can_change_status?
    exam.update_attributes status: !exam.status

    render_exam_success_json('status')
  rescue CanCan::AccessDenied
    render json: { success: false, alert: t(:no_permission) }, status: :unauthorized
  rescue => error
    render_json_error(error, 'exams.error')
  end

  def show
    authorize! :show, Exam, { on: params[:allocation_tags_ids] }
    @exam = Exam.find(params[:id])
  end

  def preview
    authorize! :show, Question, { on: params[:allocation_tags_ids] }
    @exam = Exam.find(params[:id])
    @preview = true
    @exam_questions = ExamQuestion.list(@exam.id, @exam.raffle_order).paginate(page: params[:page], per_page: 1, total_entries: @exam.number_questions) unless @exam.nil?

    render :open
  end

  private

  def exam_params
    params.require(:exam).permit(:name, :description, :duration, :start_hour, :end_hour, 
                                 :random_questions, :raffle_order, :auto_correction, 
                                 :block_content, :number_questions, :attempts, 
                                 :attempts_correction, :result_email,
                                 schedule_attributes: [:id, :start_date, :end_date])
  end

  def render_exam_success_json(method)
    render json: { success: true, notice: t(method, scope: 'exams.success') }
  end

  def verify_exam
    @exam = Exam.find(params[:id])
    @allocation_tag_id = params[:allocation_tag_id]
    @exam_user = Exam.find_or_create_exam_user(@exam, current_user.id, @allocation_tag_id)
    if params[:situation]!='corrected'
      unless (@exam.on_going? && @exam_user.has_attempt(@exam))
        redirect_to :back, alert: t('exams.error.general_message')
      end
    end  
  end
end