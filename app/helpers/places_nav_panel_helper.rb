=begin

  = Listar apenas informações em que o usuário tem alguma ligação com permissão de edição
    - verificar em qual ponto da hierarquia o usuario tem permissao para visualizar
      - listar todas as informacoes abaixo desse ponto
        - uc, oferta, turma

TODO: 
	- colocar "alt" nas imagens
	- remover o '/assets' dos caminhos de imagens
    - Ver necessidade de indexar no BD os campos de busca para melhorar a performance de tudo.
=end

module PlacesNavPanelHelper

  def places_nav_panel_helper
  
	selectedCourseName = ''
	selectedCourseValue = ''
	selectedSemesterName = ''
	selectedSemesterValue = ''
	selectedCurriculumUnitName = ''
	selectedCurriculumUnitValue = ''
	selectedGroupName = ''
	selectedGroupValue = ''
	
	selectedCourseName = params[:selectedCourseName] if params.include?(:selectedCourseName)
	selectedCourseValue = params[:selectedCourseValue] if params.include?(:selectedCourseValue)
	selectedSemesterName = params[:selectedSemesterName] if params.include?(:selectedSemesterName)
	selectedSemesterValue = params[:selectedSemesterValue] if params.include?(:selectedSemesterValue)
	selectedCurriculumUnitName = params[:selectedCurriculumUnitName] if params.include?(:selectedCurriculumUnitName)
	selectedCurriculumUnitValue = params[:selectedCurriculumUnitValue] if params.include?(:selectedCurriculumUnitValue)
	selectedGroupName = params[:selectedGroupName] if params.include?(:selectedGroupName)
	selectedGroupValue = params[:selectedGroupValue] if params.include?(:selectedGroupValue)
    
    raw %{
	#{ javascript_include_tag "places_nav_panel"}
	#{ javascript_include_tag "jquery.tokeninput.js"}
    #{ stylesheet_link_tag "places_nav_panel" }

	<script type="text/javascript">

		//Declarando caminhos para a busca do componente. Nao conseguimos colocar isso no javascript		
		var search_urls = {
			"course": "#{url_for :controller => :courses, :format => "json"}", 
			"semester": "#{url_for :controller => :offers, :format => "json"}", 
			"curriculumUnit": "#{url_for :controller => :offers, :format => "json"}",
			"group": "#{url_for :controller => :groups, :action => "list", :format => "json"}"
		};
		
		var hints = {
			"course": "#{I18n.t(:places_nav_panel_course_hint)}", 
			"semester": "#{I18n.t(:places_nav_panel_semester_hint)}", 
			"curriculumUnit": "#{I18n.t(:places_nav_panel_curriculum_unit_hint)}",
			"group": "#{I18n.t(:places_nav_panel_group_hint)}"
		};
		
		var messages = {
			"searching": "#{I18n.t(:places_nav_panel_searching_text)}", 
			"noResults": "#{I18n.t(:places_nav_panel_empty_text)}"
		};
		
		
	</script>
	
	<div class="placesNavPanel">
		<div><span 
			class="label">#{t(:course)}:</span><input 
			type="text" id="txtCourse"/>
			<input type="button" value="" class ="btShowMenu"/>
			<input type="hidden" id="selectedCourseName" name="selectedCourseName" value="#{params[:selectedCourseName]}"/>
			<input type="hidden" id="selectedCourseValue" name="selectedCourseValue" value="#{params[:selectedCourseValue]}"/>
		</div>
		<div><span 
			class="label">#{t(:semester_date)}:</span><input 
			type="text" id="txtSemester"/>
			<input type="button" value="" class ="btShowMenu"/>
			<input type="hidden" id="selectedSemesterName" name="selectedSemesterName" value="#{params[:selectedSemesterName]}"/>
			<input type="hidden" id="selectedSemesterValue" name="selectedSemesterValue" value="#{params[:selectedSemesterValue]}"/>
		</div>
		<div><span 
			class="label" style=";">#{t(:curriculum_unit)}:</span><input 
			type="text" id="txtCurriculumUnit"/>
			<input type="button" value="" class ="btShowMenu"/>
			<input type="hidden" id="selectedCurriculumUnitName" name="selectedCurriculumUnitName" value="#{params[:selectedCurriculumUnitName]}"/>
			<input type="hidden" id="selectedCurriculumUnitValue" name="selectedCurriculumUnitValue" value="#{params[:selectedCurriculumUnitValue]}"/>
		</div>
		<div><span 
			class="label">#{t(:group)}:</span><input 
			type="text" id="txtGroup"/>
			<input type="button" value="" class ="btShowMenu"/>
			<input type="hidden" id="selectedGroupName" name="selectedGroupName" value="#{params[:selectedGroupName]}"/>
			<input type="hidden" id="selectedGroupValue" name="selectedGroupValue"value="#{params[:selectedGroupValue]}"/>
		</div>
	</div>
    }
  end

end
