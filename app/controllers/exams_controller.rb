class ExamsController < ApplicationController

  include SysLog::Actions
  include IpRealHelper

  before_filter :prepare_for_group_selection, only: :index
  before_filter :get_groups_by_allocation_tags, only: [:new, :create]
  before_filter :verify_exam, only: [:open]
  layout false, except: :index

  def index
    @allocation_tag_id = active_tab[:url][:allocation_tag_id]
    authorize! :index, Exam, on: [@allocation_tag_id]
    @exams = Score.list_tool(current_user.id, @allocation_tag_id, 'exams', false, false, true)

    @can_open = can? :open, Exam, {on: @allocation_tag_id}
    @can_evaluate = can? :evaluate, Exam, { on: @allocation_tag_id }
    @is_student = current_user.is_student?([@allocation_tag_id])
  rescue => error
    render json: { success: false, alert: t(:no_permission) }, status: :unauthorized
  end

  def new
    @allocation_tags_ids = params[:allocation_tags_ids]
    @exam = Exam.new
    @exam.build_schedule(start_date: Date.today, end_date: Date.today)
    @exam.ip_reals.build
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

  # require 'will_paginate/array'
  def list
    @allocation_tags_ids = params[:groups_by_offer_id].present? ? AllocationTag.at_groups_by_offer_id(params[:groups_by_offer_id]) : params[:allocation_tags_ids]
    @selected = params[:selected]
    authorize! :list, Exam, { on: @allocation_tags_ids }

    @all_groups = Group.where(offer_id: params[:offer_id])
    @exams = Exam.exams_by_ats(@allocation_tags_ids.split(' ')).order('exams.id')#.paginate(page: params[:page], per_page: 1)
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
    @exam.ip_reals.build if @exam.ip_reals.empty?
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
    exam = Exam.find(params[:id])
    evaluative = exam.verify_evaluatives
    if exam.can_remove_groups?
      exam.destroy

      message = evaluative ? ['warning', t('evaluative_tools.warnings.evaluative')] : ['notice', t(:deleted, scope: [:exams, :success])]
      render json: { success: true, type_message: message.first,  message: message.last }
    else
      render_json_error('has_answers', 'exams.error')
    end
  rescue CanCan::AccessDenied
    render json: { success: false, alert: t(:no_permission) }, status: :unauthorized
  rescue => error
    render_json_error(error, 'exams.error')
  end

  def pre
    authorize! :open, Exam, { on: @allocation_tag_id = active_tab[:url][:allocation_tag_id] }
    @exam = Exam.find(params[:id])
    @situation = params[:situation]
    verify_ip!(@exam.id, :exam, @exam.controlled, :error_text_min)
    acs = @exam.academic_allocations
    ac_id = (acs.size == 1 ? acs.first.id : acs.where(allocation_tag_id: @allocation_tag_id).first.id)
    @acu = AcademicAllocationUser.find_or_create_one(ac_id, @allocation_tag_id, current_user.id, nil, true)

    last_attempt = @acu.exam_user_attempts.last

    raise 'time' unless @exam.on_going?
    raise 'attempt' unless @acu.has_attempt(@exam)
    @total_attempts  = @acu.count_attempts rescue 0

    if (last_attempt.try(:uninterrupted_or_ended, @exam)) && @total_attempts == @exam.attempts
      redirect_to result_user_exam_path(@exam)
    else
      @total_time = (last_attempt.try(:complete) ? 0 : last_attempt.try(:get_total_time)) || 0
      
      # end_hour = @exam.end_hour.blank? ? '23:59:59' : @exam.end_hour
      # exam_end = @exam.schedule.end_date.to_s+' '+end_hour.to_s
      # exame_datetime_end = Time.parse(exam_end)
      # difference_minutes = (exame_datetime_end - current_time_db) / 60
      # @duration = (difference_minutes.to_i > @exam.duration.to_i) ? (@exam.duration-(@total_time/60)) : difference_minutes

      @text = if !last_attempt.blank? && !last_attempt.try(:complete) && !@exam.uninterrupted
        t("exams.pre.continue")
      else
        t("exams.pre.button")
      end
      render :pre
    end

  rescue => error
    render text: (I18n.translate!("exams.error.#{error}", raise: true) rescue t("exams.error.general_message"))
  end

  def open
    @exam_questions = ExamQuestion.list(@exam, @last_attempt).paginate(page: params[:page], per_page: 1, total_entries: @exam.number_questions) unless @exam.nil?
    @total_time = (@last_attempt.try(:complete) ? 0 : @last_attempt.try(:get_total_time)) || 0
    # end_hour = @exam.end_hour.blank? ? '23:59:59' : @exam.end_hour
    # exam_end = @exam.schedule.end_date.to_s+' '+end_hour.to_s
    # exame_datetime_end = Time.parse(exam_end)
    # difference_minutes = (exame_datetime_end - current_time_db) / 60
    # @duration = (difference_minutes.to_i > @exam.duration.to_i) ? @exam.duration : difference_minutes

    if (@situation == 'finished' || @situation == 'corrected' || @situation == 'evaluated')
      mod_correct_exam = @exam.attempts_correction
      @exam_user_attempt = ExamUserAttempt.where(id: params[:exam_user_attempt_id]).first
      @disabled = true

      @exam_questions = ExamQuestion.list_correction(@exam.id).paginate(page: params[:page], per_page: 1, total_entries: @exam.number_questions) unless @exam.blank?
      @exam_user_attempt = Exam.get_exam_user_attempt(mod_correct_exam, @acu.id) if (mod_correct_exam != 1)

      @list_eua = ExamUserAttempt.where(academic_allocation_user_id: @acu.id)
      if mod_correct_exam == 1 && !params[:exam_user_attempt_id]  && params[:pdf].to_i != 1
        render :open_result
      else
        @last_attempt = @exam.responses_question_user(@acu.id, params[:exam_user_attempt_id])
        if params[:pdf].to_i == 1
          @grade_pdf = @exam_user_attempt.grade
          @ats = AllocationTag.find(@allocation_tag_id)
          @exam_questions = ExamQuestion.list_correction(@exam.id, @exam.raffle_order) unless @exam.nil?
          @pdf = 1

          send_data ReportsHelper.result_exam(@ats, @exam, @user, @grade_pdf, @exam_questions, @preview, @last_attempt, @disabled).render, :filename => "#{t('exams.result_exam.title_pdf', name: @exam.name)}.pdf", :type => "application/pdf", disposition: 'inline'

        else
         render :open
        end
      end
    else
      verify_ip!(@exam.id, :exam, @exam.controlled, :error_text)

      respond_to do |format|
        format.html
        format.js
      end
    end
  rescue CanCan::AccessDenied
    render text: t(:no_permission)
  rescue => error
    render text: error.to_s
  end

  def result_exam_user
    @user_id = current_user.id
    begin
      authorize! :open, Exam, { on: @allocation_tag_id = active_tab[:url][:allocation_tag_id] }
    rescue
      authorize! :evaluate, Exam, { on: @allocation_tag_id }
      @user_id = params[:user_id]
    end
    @exam = Exam.find(params[:id])
    raise 'uninterrupted' if @exam.uninterrupted && !@exam.ended?
    raise 'dates' unless @exam.ended? || (@exam.started? && @exam.immediate_result_release)

    acs = @exam.academic_allocations
    @ac = (acs.size == 1 ? acs.first : acs.where(allocation_tag_id: active_tab[:url][:allocation_tag_id]).first)
    @acu = AcademicAllocationUser.find_one(@ac.id, @user_id)
    @frequency = @ac.frequency && (can? :evaluate, Exam, { on: @allocation_tag_id })
    raise 'empty' if @acu.nil? && !@frequency

    @grade = ((@acu.try(:grade).blank? || @exam.can_correct?(@user_id, AllocationTag.find(@allocation_tag_id).related)) ? @exam.recalculate_grades(@user_id, "#{[@allocation_tag_id].flatten.join(',')}", true).first : @acu.grade)

    @attempts = @acu.try(:exam_user_attempts) || []
    @attempt = case @exam.attempts_correction
               when Exam::GREATER; @attempts.order('grade DESC').first
               when Exam::LAST; @attempts.last
               end
    @scores_exam = @exam.exam_questions.where(use_question: true).sum(:score)
  rescue CanCan::AccessDenied
    render text: t(:no_permission)
  rescue => error
    render text: (I18n.translate!("exams.error.#{error}", raise: true) rescue t("exams.error.general_message"))
  end

  def complete
    exam = Exam.find(params[:id])
    acs = exam.academic_allocations
    acu = AcademicAllocationUser.find_one((acs.size == 1 ? acs.first.id : acs.where(allocation_tag_id: active_tab[:url][:allocation_tag_id]).first.id), current_user.id, nil, true)
    if acu.finish_attempt(get_remote_ip)
      if (params[:error])
        respond_to do |format|
          format.js { render :js => "validation_error('#{I18n.t('exam_responses.error.' + params[:error] + '')}');" }
        end
      else
        user_session[:blocking_content] = Exam.verify_blocking_content(current_user.id)
        render_exam_success_json('finish')
      end
    end
  rescue => error
    render_json_error(error, 'exams.error')
  end

  def calculate_user_grade
    exam = Exam.find(params[:id])
    user_id = current_user.id
    at_id = active_tab[:url][:allocation_tag_id]
    if params.include?(:user_id) && params[:user_id].to_i != current_user.id
      authorize! :evaluate, Exam, { on: at_id }
      user_id = params[:user_id]
    end
    raise 'not_finished' unless exam.ended? || (exam.started? && exam.immediate_result_release)
    raise 'result_release_date' unless exam.allow_calculate_grade?
    grade, wh = exam.recalculate_grades(user_id, at_id, true)

    ac = AcademicAllocation.where(allocation_tag_id: at_id, academic_tool_id: exam.id, academic_tool_type: 'Exam').first
    acu = AcademicAllocationUser.find_one(ac.try(:id), user_id)
    if params.include?(:score_type) && !acu.blank?
      return_acu_result(acu, at_id, params[:score_type])
    else
      render json: { success: true, grade: grade, wh: wh, status: t('exams.situation.corrected'), notice: t('calculate_grade', scope: 'exams.list') }
    end

  rescue => error
    render_json_error(error, 'exams.error')
  end

  def calculate_grade
    allocation_tags_ids = params.include?(:allocation_tags_ids) ? params[:allocation_tags_ids] : active_tab[:url][:allocation_tag_id]
    authorize! :evaluate, Exam, { on: allocation_tags_ids }
    ats = allocation_tags_ids.gsub(' ', ",") rescue allocation_tags_ids

    exam = Exam.find(params[:id])
    raise 'not_finished' unless exam.ended? || (exam.started? && exam.
      immediate_result_release)
    raise 'result_release_date' unless exam.allow_calculate_grade?
    exam.recalculate_grades((exam.immediate_result_release ? params[:user_id] : nil), ats, true)
    if acu = AcademicAllocationUser.find_one(params[:ac_id], params[:user_id])
      if params.include?(:score_type)
        return_acu_result(acu, allocation_tags_ids, params[:score_type])
      else
        render json: { success: true, notice: t('calculate_grade', scope: 'exams.list'), situation: t('scores.situation.corrected'), grade: acu.grade }
      end
    else
      render json: { success: true, notice: t('calculate_grade', scope: 'exams.list'), situation: t('scores.situation.corrected') }
    end
  rescue => error
    render_json_error(error, 'exams.error')
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

  require 'will_paginate/array'
  def preview
    authorize! :show, Question, { on: params[:allocation_tags_ids] }
    @exam = Exam.find(params[:id])
    @preview = true

    @exam_questions = ExamQuestion.list(@exam, nil, true, (params[:page].blank? ? nil : session[:preview_random_questions]))

    session[:preview_random_questions] = (@exam_questions.map(&:order) - [@exam_questions.first.order]).insert(0, @exam_questions.first.order) if (@exam.raffle_order && params[:page].blank?)

    if !session[:preview_random_questions].blank? && params[:page].blank?
      @exam_questions = [@exam_questions.first].paginate(page: params[:page], per_page: 1, total_entries: @exam.number_questions)
    else
      @exam_questions = @exam_questions.paginate(page: params[:page], per_page: 1, total_entries: @exam.number_questions)
    end

    render :open
  end

  def percentage
    authorize! :open, Exam, { on: allocation_tag_id = active_tab[:url][:allocation_tag_id] }
    exam = Exam.find(params[:id])
    acs = exam.academic_allocations
    ac_id = (acs.size == 1 ? acs.first.id : acs.where(allocation_tag_id: allocation_tag_id).first.id)
    acu = AcademicAllocationUser.find_one(ac_id, current_user.id, nil, true)
    @percentage = Exam.percent(exam.number_questions, acu.answered_questions)
  rescue => error
    render text: (I18n.translate!("exams.error.#{error}", raise: true) rescue t("exams.error.general_message"))
  end

  private

  def exam_params
    params.require(:exam).permit(:name, :description, :duration, :start_hour, :end_hour,
                                 :random_questions, :raffle_order, :auto_correction,
                                 :block_content, :number_questions, :attempts, :controlled,
                                 :attempts_correction, :result_email, :uninterrupted, :result_release, :immediate_result_release,
                                 schedule_attributes: [:id, :start_date, :end_date],
                                 ip_reals_attributes: [:id, :ip_v4, :ip_v6, :use_local_network, :_destroy])
  end

  def render_exam_success_json(method)
    render json: { success: true, notice: t(method, scope: 'exams.success') }
  end

  def verify_time
    if params[:situation] == 'finished' || params[:situation] == 'corrected'
      raise 'not_finished' unless @exam.ended? || (@exam.started? && @exam.immediate_result_release)
    else
      raise 'time' unless @exam.on_going?
    end
  end

  def verify_exam
    @exam = Exam.find(params[:id])
    @allocation_tag_id = active_tab[:url][:allocation_tag_id]
    acs = @exam.academic_allocations
    ac_id = (acs.size == 1 ? acs.first.id : acs.where(allocation_tag_id: @allocation_tag_id).first.id)
    @situation = params[:situation]

    if params.include?(:user_id) && params[:user_id].to_i != current_user.id
      @user = params[:user_id]
      authorize! :evaluate, Exam, on: [@allocation_tag_id].flatten
      @acu = AcademicAllocationUser.find_one(ac_id, @user, nil, true) if @acu.blank?
      @last_attempt = @acu.exam_user_attempts.last
    else
      unless user_session[:exams].include?(params[:id])
        authorize! :open, Exam, { on: @allocation_tag_id }
        verify_time
        user_session[:exams] << params[:id]

        @acu = AcademicAllocationUser.find_or_create_one(ac_id, @allocation_tag_id, current_user.id, nil, true)
        raise 'attempts' unless @acu.has_attempt(@exam) || ['corrected', 'finished', 'not_corrected', 'evaluated'].include?(@acu.status_exam)
      else
        @acu = AcademicAllocationUser.find_one(ac_id, current_user.id, nil, true) if @acu.blank?
      end

      @user = current_user.id
      user_session[:blocking_content] = Exam.verify_blocking_content(@user) if params[:page].blank?
      @last_attempt = @acu.find_or_create_exam_user_attempt(get_remote_ip, !params[:page].blank?)
      @disabled = false
    end

    if ['corrected', 'evaluated'].include?(@situation)
      raise 'not_corrected' if @acu.blank? || @acu.grade.blank?
      raise 'no_attempt' if @last_attempt.blank?
      raise 'result_release_date' unless @exam.allow_calculate_grade?
      @exam.recalculate_grades(@user, @allocation_tag_id, true) if @acu.exam_user_attempts.where(grade: nil).any?
    elsif  @user != current_user.id
      raise CanCan::AccessDenied
    end

  rescue => error
    render text: (I18n.translate!("exams.error.#{error}", raise: true) rescue t("exams.error.general_message"))
  end

  def return_acu_result(acu, at_id, score_type)
    ac = acu.academic_allocation

    score = Score.evaluative_frequency_situation(at_id, acu.user_id, acu.group_assignment_id, ac.academic_tool_id, ac.academic_tool_type.downcase.delete('_'), (score_type.blank? ? 'not_evaluative' : score_type)).first.situation

    render json: { success: true, situation: t("scores.index.#{score}"), class_td: score, situation_complete: t(score.to_sym), tool: ac.academic_tool_type, score_type: score_type || '', ac_id: ac.id, user_id: acu.user_id, group_id: acu.group_assignment_id, notice: t('exams.list.calculate_grade'), show_element: '.open_exam', grade: acu.grade, wh: acu.working_hours }
  rescue => error
    render json: { success: false,  alert: error }
  end

end
