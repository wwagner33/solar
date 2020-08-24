##########
# Variaveis de sessao do usuario
#
# user_session {
#   :current_page,
#   :menu,
#   :tabs => {
#     :active => 'name',
#     :opened => {
#       'name' => {
#         :breadcrumb => [],
#         :url => {}
#       }
#     }
#   }
# }
##########

class ApplicationController < ActionController::Base

  include ApplicationHelper

  protect_from_forgery

  before_filter :authenticate_user!, except: [:verify_cpf, :api_download, :lesson_media, :tutorials, :privacy_policy, :comment_media] # devise
  before_filter :set_locale, :start_user_session, :current_menu_context, :another_level_breadcrumb, :get_theme
#  after_filter :log_navigation

  # before_filter :check_concurrent_session

  rescue_from CanCan::AccessDenied do |exception|
    respond_to do |format|
      format.html {
        begin
          active_tab[:breadcrumb].delete_at(-1) if active_tab[:breadcrumb].count > 1 # not home
          raise 'error' if request.referer == request.original_url
          redirect_to :back, alert: t(:no_permission)
        rescue # ActionController::RedirectBackError
          redirect_to home_path, alert: t(:no_permission)
        end
      }
      format.json { render json: { msg: t(:no_permission), alert: t(:no_permission) }, status: :unauthorized }
      format.js { render js: "flash_message('#{t(:no_permission)}', 'alert');" }
    end
  end


  if Rails.env != 'development'
    rescue_from ActiveRecord::RecordNotFound do |exception|
      #logar: exception.message
      respond_to do |format|
        format.html { redirect_to home_path, alert: t(:object_not_found) }
        format.json { render json: { msg: t(:object_not_found)}, status: :not_found }
      end
    end

    rescue_from ActiveRecord::AssociationTypeMismatch do |exception|
      respond_to do |format|
        format.html { redirect_to home_path, alert: t(:not_associated) }
        format.json { render json: { msg: t(:not_associated)}, status: :unauthorized }
      end
    end

    rescue_from ActionView::Template::Error do |exception|
      respond_to do |format|
        format.html { redirect_to((user_signed_in? ? home_path : login_path), alert: t(:cant_build_page)) }
        format.json { render json: { msg: t(:cant_build_page)}, status: :unauthorized }
      end
     end
  end

  def start_user_session
    return unless user_signed_in?
    user_session[:tabs] = {
      opened: {
        'Home' => {
          breadcrumb: [{ name: 'Home', url: activate_tab_path(name: 'Home', context: Context_General) }],
          url: { context: Context_General }
        }
      }, active: 'Home'
    } unless user_session.include?(:tabs)
  end

  def another_level_breadcrumb
    same_level_for_all = 1 # ultimo nivel, por enquanto o breadcrumb só comporta 3 níveis
    user_session[:tabs][:opened][user_session[:tabs][:active]][:breadcrumb][same_level_for_all] = { name: params[:bread], url: params.except(:page) } if params[:bread].present?
  end

  def current_menu_context
    return unless user_signed_in?

    # contexto indicado eh diferente do contexto da aba ativa
    contexts = params['contexts'].split(',').map(&:to_i) rescue []
    set_active_tab_to_home if ((!contexts.empty? && !contexts.include?(active_tab[:url][:context])) || controller_path == 'devise/users')
  end

  def set_active_tab(tab_id)
    user_session[:tabs][:active] = tab_id
  end

  def set_active_tab_to_home
    clear_breadcrumb_home
    set_active_tab('Home')
  end

  def active_tab
    user_session[:tabs][:opened][user_session[:tabs][:active]] if user_signed_in?
  end

  def clear_breadcrumb_home
    user_session[:tabs][:opened]['Home'][:breadcrumb] = [user_session[:tabs][:opened]['Home'][:breadcrumb].first]
  end

  def prepare_for_pagination
    @current_page = user_session[:current_page]
    user_session[:current_page] = nil

    @current_page = params[:current_page] if @current_page.nil?
    @current_page = '1' if @current_page.nil?
  end

  def hold_pagination
    user_session[:current_page] = @current_page

  end

  def prepare_for_group_selection
    @can_select_group = true
  end

  def get_group_allocation_tag
     return unless active_tab[:url][:context] == Context_Curriculum_Unit.to_i

    # verifica se o grupo foi passado e se é um grupo válido
    unless params[:selected_group].present? && !!(allocation_tag_id_group = AllocationTag.find_by_group_id(params[:selected_group]).try(:id))
      allocation_tag = AllocationTag.find(active_tab[:url][:allocation_tag_id])
      # allocation_tag_id_group = (params[:selected_group] = allocation_tag.group_id).nil? ? RelatedTaggable.where('group_id IN (?)', current_user.groups(nil, Allocation_Activated, nil, nil, active_tab[:url][:id]).pluck(:id)).first.group_at_id : allocation_tag.id
      params[:selected_group] = allocation_tag.group_id
      allocation_tag_id_group = if params[:selected_group].blank?
        profiles_ids = current_user.profiles_with_access_on('show', 'curriculum_units', nil, true)
        RelatedTaggable.where('group_id IN (?)', current_user.groups(profiles_ids, Allocation_Activated, nil, nil, active_tab[:url][:id]).pluck(:id)).first.group_at_id
      else
        allocation_tag.id
      end
    end

    user_session[:tabs][:opened][user_session[:tabs][:active]][:url][:allocation_tag_id] = allocation_tag_id_group
    log_access(allocation_tag_id_group) # save access
  end

  def select_group
    prepare_for_group_selection
    get_group_allocation_tag

    redirect_to URI(request.referer).path, selected_group: params[:selected_group]
  end

  def after_sign_in_path_for(resource_or_scope)
    LogAccess.login(user_id: current_user.id, ip: get_remote_ip) rescue nil
    user_session[:lessons] = []
    user_session[:exams] = []
    user_session[:blocking_content] = []
    super
  end

  def get_groups_by_tool(tool)
    @groups = tool.groups
  end

  def get_groups_by_allocation_tags(ats = nil)
    ats = params.include?(:allocation_tags_ids) ? params[:allocation_tags_ids].split(' ').flatten : [active_tab[:url][:allocation_tag_id]].compact if ats.blank?
    @groups = Group.includes(:allocation_tag).where(allocation_tags: { id: ats })
  end

  def set_locale
    if user_signed_in?
      personal_options = PersonalConfiguration.find_or_create_by(user_id: current_user.id)
      personal_options.update_attributes(default_locale: params[:locale]) if (params[:locale].present? && params[:locale].to_s != personal_options.default_locale.to_s)
      params[:locale] = personal_options.default_locale
    end

    I18n.locale = ['pt_BR', 'en_US'].include?(params[:locale]) ? params[:locale] : I18n.default_locale
    params.delete(:locale) if user_signed_in?
  end

  def get_theme
    if user_signed_in?
      current_theme = PersonalConfiguration.find_by_user_id(current_user.id)
      user_session[:theme] = current_theme.theme
    end
  end

  ## Parametros de locale para paginas externas
  def default_url_options(options={})
    params.include?('locale') ? {locale: params[:locale]} : {}
  end

  def set_current_user
    User.current = current_user
  end

  def get_remote_ip
    request.headers['HTTP_CLIENT_IP'] || request.remote_ip
  end

  def get_access_token
    request.headers['APP_CLIENT_TOKEN'] || params[:access_token]
  end

  def client_network_ip
    render json: { network_ip: get_remote_ip }
  end

  private

    def opened_or_new_tab?(tab_id)
      (user_session[:tabs][:opened].has_key?(tab_id)) or (user_session[:tabs][:opened].length < Max_Tabs_Open.to_i)
    end

    def set_session_opened_tabs(hash_url, params_url)
      user_session[:tabs][:opened][params[:id]] = { breadcrumb: [{name: params[:name], tab: params[:tab] || params[:name], url: params_url}], url: hash_url }
      set_active_tab params[:id]
    end

    def crud_action
      case params[:action]
      when 'new', 'create'
        :create
      when 'edit', 'update'
        :update
      end
    end

    def log_access(allocation_tag_id)
      LogAccess.group(user_id: current_user.id, allocation_tag_id: allocation_tag_id, ip: get_remote_ip) rescue nil if (user_session[:tabs][:opened][user_session[:tabs][:active]][:url][:context].to_i == Context_Curriculum_Unit)
    end

  #salva o log de navegação do usuário
  def log_navigation

    context_id = params[:contexts].blank? ? params[:context] : params[:contexts]
    allocation_tag_id = user_session[:tabs][:opened][user_session[:tabs][:active]][:url][:allocation_tag_id] rescue params[:allocation_tag_id]

    unless allocation_tag_id.nil?

      if params[:bread] && !params[:user_id]
        menu = Menu.find_by_name(params[:bread])
        session[:menu_log] = menu
      elsif params[:selected_group] && session[:menu_log]
        context_id = Context_Curriculum_Unit
        menu = session[:menu_log]
        LogNavigation.create(user_id: current_user.id, context_id: context_id, allocation_tag_id: allocation_tag_id)
      elsif session[:menu_log] # submenu do curso
        menu_log = session[:menu_log]
        sub_log_id = params[:id]
        discussion_log_id = params[:discussion_id]
        lesson_notes_id = params[:lesson_id]
        user_log_id = params[:user_id]
        student_log_id = params[:student_id]
        group_assignment_log_id = params[:group_id]
        digital_class_log = params[:url]
        zip_download = true if (params[:action] == 'download' && params[:type]) || params[:zip]
      end

      if menu
        LogNavigation.create(user_id: current_user.id, menu_id: menu.id, context_id: context_id, allocation_tag_id: allocation_tag_id)
      elsif !context_id.nil?
        LogNavigation.create(user_id: current_user.id, context_id: context_id, allocation_tag_id: allocation_tag_id) # entrando em um curso
      end

      # chama o metodo para salva o log do submenu acessado
      log_navigation_sub(menu_log, discussion_log_id, user_log_id, sub_log_id, student_log_id, group_assignment_log_id, lesson_notes_id, digital_class_log, zip_download) if discussion_log_id || user_log_id || sub_log_id || student_log_id || group_assignment_log_id || zip_download || lesson_notes_id || digital_class_log

    else
      LogNavigation.create(user_id: current_user.id, context_id: Context_General) if params[:id] == 'Home'
    end
  rescue => error
    Rails.logger.info "[ERROR] [Log Navigation] [#{Time.now}] #{error}"
  end

  # salva o log de acesso ao submenu
  def log_navigation_sub(menu_log, discussion_log_id, user_log_id, sub_log_id, student_log_id, group_assignment_log_id, lesson_notes_id, digital_class_log, zip_download)

    case menu_log.id
      when 101
        unless params[:controller] == 'access_control'
          lesson_log_id = sub_log_id || lesson_notes_id
          lesson = Lesson.find(lesson_log_id)
          lesson_notes = true if lesson_notes_id
          lesson_name = lesson.is_link? ? lesson.address : lesson.name
        end
      when 102
        support_material_file = if zip_download
          'zip'
        else
          spf = SupportMaterialFile.find(sub_log_id)
          spf.url.blank? ? spf.attachment_file_name : spf.url
        end
      when 103
        digital_class_url = digital_class_log
      when 202
        assignments_id = sub_log_id
      when 203
        exams_id = sub_log_id
      when 204
        session[:tool_type] = params[:tool_type] if params[:tool_type]
        assignments_id = sub_log_id if session[:tool_type] == 'Assignment'
        webconferences_id = sub_log_id if session[:tool_type] == 'Webconference'
        exams_id = sub_log_id if session[:tool_type] == 'Exam'
        chat_rooms_id = sub_log_id if session[:tool_type] == 'ChatRoom'
      when 205
        chat_rooms_id = sub_log_id
        unless params[:academic_allocation_id] # para acesso ao chat
          hist_chat_rooms_id = sub_log_id      # para acesso ao historico do chat
        end
      when 206
        webconferences_id = sub_log_id
        webconference = params[:action] == 'access'
      when 208
        score_professor = true if params[:tool]
        session[:tool_type] = params[:tool_type] if params[:tool_type]
        assignments_id = sub_log_id if session[:tool_type] == 'Assignment'
        webconferences_id = sub_log_id if session[:tool_type] == 'Webconference'
        exams_id = sub_log_id if session[:tool_type] == 'Exam'
        chat_rooms_id = sub_log_id if session[:tool_type] == 'ChatRoom'
      when 303
        bibliography = if zip_download
          'zip'
        else
          bib = Bibliography.find(sub_log_id)
          bib.attachment_file_name.blank? ? (bib.url.blank? ? bib.address : bib.url) : bib.attachment_file_name
        end
      when 304 #&& params[:controller] == 'public_files'
        if zip_download
          public_file_name = 'zip'
        else
          if sub_log_id
            public_file = PublicFile.find(sub_log_id)
            public_file_name = public_file.attachment_file_name rescue nil
            user_log_id = public_file.user_id unless user_log_id
          end
        end
        public_area = true if user_log_id
    end

    if (!support_material_file.blank? || assignments_id || exams_id || chat_rooms_id || webconferences_id || discussion_log_id || lesson_log_id || !bibliography.blank? || student_log_id || public_area || hist_chat_rooms_id || digital_class_url || (user_log_id && score_professor))
      # para o acompanhamento do professor
      #assignments_id = sub_log_id if student_log_id
      ultimo_log_nav = LogNavigation.where('user_id = ? AND menu_id = ?', current_user.id, menu_log.id).last # pega o log de navegação para o sub log.
      LogNavigationSub.create(log_navigation_id: ultimo_log_nav.id, support_material_file: support_material_file, discussion_id: discussion_log_id, lesson_id: lesson_log_id, assignment_id: assignments_id, exam_id: exams_id, user_id: user_log_id, chat_room_id: chat_rooms_id, student_id: student_log_id, group_assignment_id: group_assignment_log_id, webconference_id: webconferences_id, bibliography: bibliography, public_area: public_area, lesson: lesson_name, public_file_name: public_file_name, hist_chat_room_id: hist_chat_rooms_id, webconference_record: webconference, lesson_notes: lesson_notes, digital_class_lesson: digital_class_url)
      #session.delete(:tool_type)
    end
  rescue => error
    Rails.logger.info "[ERROR] [Log Navigation] [#{Time.now}] #{error}"
  end

  def api_guard_with_access_token_or_authenticate
    current_user = nil
    user_session = []

    unless get_access_token.blank? || !user_session.blank?
      access_token = Doorkeeper::AccessToken.authenticate(get_access_token)
      case Oauth2::AccessTokenValidationService.validate(access_token, scopes: [])
      when Oauth2::AccessTokenValidationService::INSUFFICIENT_SCOPE
        Rails.logger.info "[API] [ERROR] [#{env["REQUEST_METHOD"]} #{env["PATH_INFO"]}] [#{code}] message: Error while checking for access_token permission - INSUFFICIENT_SCOPE"
        raise InsufficientScopeError.new(scopes)

      when Oauth2::AccessTokenValidationService::EXPIRED
        Rails.logger.info "[API] [ERROR] [#{env["REQUEST_METHOD"]} #{env["PATH_INFO"]}] [#{code}] message: Error while checking for access_token permission - EXPIRED"
        raise ExpiredError

      when Oauth2::AccessTokenValidationService::REVOKED
        Rails.logger.info "[API] [ERROR] [#{env["REQUEST_METHOD"]} #{env["PATH_INFO"]}] [#{code}] message: Error while checking for access_token permission - REVOKED"
        raise RevokedError

      when Oauth2::AccessTokenValidationService::VALID
        sign_in(:user, User.find(access_token.resource_owner_id))

        if current_user.blank?
          current_user = User.find(access_token.resource_owner_id) rescue nil
        end

        User.current = current_user
        @user_session_exam = Exam.verify_blocking_content(current_user.id) || false
      end
    else
      @user_session_exam = false
      authenticate_user!
      user_session[:blocking_content] = Exam.verify_blocking_content(current_user.try(:id) || User.current.try(:id)) if user_session[:blocking_content].blank?
    end
  end

  def check_concurrent_session
    if !current_user.nil? && !(user_session[:token] == current_user.session_token)
      sign_out current_user
      redirect_to login_path, alert: t('users.errors.multiple_sessions')
    else
      return true
    end
  end

  # def current_time_db
  #   result = ActiveRecord::Base.connection.execute("SELECT current_time")
  #   Time.parse(result.to_a[0]['current_time'])
  # end
end
