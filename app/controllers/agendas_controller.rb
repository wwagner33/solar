class AgendasController < ApplicationController
  before_filter :prepare_for_group_selection, only: :list

  layout false, only: [:calendar, :dropdown_content]

  def index
     # se não estiver em uma uc específica, recupera as allocations tags ativadas do usuário
    @allocation_tags = (active_tab[:url][:allocation_tag_id].nil?) ? current_user.activated_allocation_tag_ids(true, true) : AllocationTag.find(active_tab[:url][:allocation_tag_id]).related.uniq
    @link            = not(params[:list_all_schedule].nil?) # apresentacao dos links de todas as schedules
    @schedule        = Agenda.events(@allocation_tags, params[:date])
    render layout: false
  end

  def list
    @allocation_tags_ids = (active_tab[:url].include?(:allocation_tag_id) ?  AllocationTag.find(active_tab[:url][:allocation_tag_id]).related.flatten : (params[:allocation_tags_ids].blank? ? current_user.activated_allocation_tag_ids(true, true) : params[:allocation_tags_ids]))
    @allocation_tags_ids = @allocation_tags_ids.join(" ") unless @allocation_tags_ids.nil?

    render action: :calendar
  end

  # calendário de eventos
  def calendar
    @allocation_tags_ids = (active_tab[:url].include?(:allocation_tag_id) ? AllocationTag.find(active_tab[:url][:allocation_tag_id]).related.flatten.join(" ") : params[:allocation_tags_ids])
    @access_forms = Event.descendants.collect{ |model| model.to_s.tableize.singularize if model.constants.include?("#{params[:selected].try(:upcase)}_PERMISSION".to_sym) }.compact.join(",")
  end

  # eventos para exibição no calendário
  def events
    # recupera as allocation_tags relacionadas da turma informada caso esteja em uma turma; se tiver "allocation_tags_ids" sem ser vazio caso esteja na edição; recupera todas as allocation_tag_ids
    # que o usuário interage caso seja a agenda geral
    @allocation_tags_ids = (active_tab[:url].include?(:allocation_tag_id) ? AllocationTag.where(id: active_tab[:url][:allocation_tag_id]).map(&:related).flatten : (
        (params.include?(:allocation_tags_ids) and not(params[:allocation_tags_ids].blank?)) ? params[:allocation_tags_ids].split(" ").flatten : current_user.activated_allocation_tag_ids(true, true)
      )
    ).uniq

    authorize! :calendar, Agenda, {on: @allocation_tags_ids, read: true}

    @events = [Event.all_descendants(@allocation_tags_ids, current_user, params.include?("list"), params)].flatten.map(&:schedule_json).uniq

    @allocation_tags_ids = @allocation_tags_ids.join(" ")
    render json: @events
  end

  def dropdown_content
    @model_name = model_by_param_type(params[:type])
    @event      = @model_name.find(params[:id])
    @groups     = @event.groups
    @allocation_tags_ids = params[:allocation_tags_ids]
  end

  private

    def model_by_param_type(type)
      type.constantize if ['Assignment', 'Discussion', 'ChatRoom', 'ScheduleEvent', 'Lesson'].include?(type)
    end

end
