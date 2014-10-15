module V1
  class Offers < Base

     segment do

      before { verify_ip_access! }

      namespace :offer do 
        desc "Criação de oferta/semestre"
        params do
          requires :name, type: String
          requires :course_id, :curriculum_unit_id, type: Integer
          requires :offer_start, :offer_end, type: Date
          optional :enrollment_start, :enrollment_end, type: Date
        end
        post "/" do
          begin        
            offer = creates_offer_and_semester(params[:name], {start_date: params[:offer_start].try(:to_date), end_date: params[:offer_end].try(:to_date)}, {start_date: params[:enrollment_start], end_date: params[:enrollment_end]}, {curriculum_unit_id: params[:curriculum_unit_id], course_id: params[:course_id]})
            {id: offer.id}
          rescue => error
            error!(error, 422)
          end
        end

        desc "Edição de oferta/semestre"
        params do
          optional :offer_start, :offer_end, :enrollment_start, :enrollment_end, type: Date
          at_least_one_of :offer_start, :offer_end, :enrollment_start, :enrollment_end
        end
        put ":id" do
          begin
            update_dates(Offer.find(params[:id]), params)
            {ok: :ok}
          rescue => error
            error!({error: error}, 422)
          end
        end
      end # offer

      namespace :sav do

        desc "Todos os semestres"
        get :semesters, rabl: "semesters/list" do
          @semesters = Semester.order('name desc').uniq
        end

      end # sav

      desc "Todos os semestres"
      get :semesters, rabl: "semesters/list" do
        @semesters = Semester.order('name desc').uniq
      end

    end # segment

  end
end
