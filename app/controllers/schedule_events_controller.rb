class ScheduleEventsController < ApplicationController

  include SysLog::Actions

  before_filter :get_groups_by_allocation_tags, only: [:new, :create]

  before_filter only: [:edit, :update, :show] do |controller|
    @allocation_tags_ids = params[:allocation_tags_ids]
    get_groups_by_tool(@schedule_event = ScheduleEvent.find(params[:id]))
  end

  layout false

  def show
    authorize! :show, ScheduleEvent, on: @allocation_tags_ids
  end

  def new
    authorize! :new, ScheduleEvent, on: @allocation_tags_ids = params[:allocation_tags_ids]

    @schedule_event = ScheduleEvent.new
    @schedule_event.build_schedule(start_date: Date.today, end_date: Date.today)
  end

  def create
    authorize! :new, ScheduleEvent, on: @allocation_tags_ids = params[:allocation_tags_ids]

    @schedule_event = ScheduleEvent.new schedule_event_params
    @schedule_event.allocation_tag_ids_associations = @allocation_tags_ids.split(" ").flatten

    if @schedule_event.save
      render_schedule_event_success_json('created')
    else
      render :new
    end
  rescue => error
    request.format = :json
    raise error.class
  end

  def edit
    authorize! :edit, ScheduleEvent, on: @allocation_tags_ids
  end

  def update
    authorize! :edit, ScheduleEvent, on: @schedule_event.academic_allocations.pluck(:allocation_tag_id)

    if @schedule_event.can_change? and @schedule_event.update_attributes(schedule_event_params)
      render_schedule_event_success_json('updated')
    else
      render :edit
    end
  rescue => error
    request.format = :json
    raise error.class
  end

  def destroy
    @schedule_event = ScheduleEvent.find(params[:id])
    authorize! :destroy, ScheduleEvent, on: @schedule_event.academic_allocations.pluck(:allocation_tag_id)

    if @schedule_event.can_change? and @schedule_event.try(:destroy)
      render_schedule_event_success_json('deleted')
    else
      render json: {success: false, alert: t('schedule_events.error.deleted')}, status: :unprocessable_entity
    end
  rescue => error
    request.format = :json
    raise error.class
  end

  private

    def schedule_event_params
      params.require(:schedule_event).permit(:title, :description, :type_event, :start_hour, :end_hour, :place, :integrated, schedule_attributes: [:id, :start_date, :end_date])
    end

    def render_schedule_event_success_json(method)
      render json: {success: true, notice: t(method, scope: 'schedule_events.success')}
    end

end
