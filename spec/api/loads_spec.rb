require "spec_helper"

describe "Loads" do

  fixtures :all

  describe ".curriculum_units" do

    describe "editors" do

      context "with valid ip" do
        context "and existing users" do
          it {
            editors = {editores: {
              codDisciplina: "RM404",
              editores: User.where(username: %w(user3 user4)).map(&:cpf)
            }}

            expect{
              post "/api/v1/load/curriculum_units/editors", editors

              response.status.should eq(201)
              response.body.should == {ok: :ok}.to_json
            }.to change{Allocation.count}.by(2)
          }
        end

        context "and non existing users" do
          it {
            editors = {editores: {
              codDisciplina: "RM404",
              editores: User.where(username: %w(userDontExist user3)).map(&:cpf) #only one user exists
            }}
            
            expect{
              post "/api/v1/load/curriculum_units/editors", editors

              response.status.should eq(201)
              response.body.should == {ok: :ok}.to_json
            }.to change{Allocation.count}.by(1)
          }
        end

        context "and non existing uc" do
          it {
            editors = {editores: {
              codDisciplina: "UC01",
              editores: User.where(username: %w(user3 user4)).map(&:cpf) #only one user exists
            }}
            
            expect{
              post "/api/v1/load/curriculum_units/editors", editors

              response.status.should eq(404)
            }.to change{Allocation.count}.by(0)
          }
        end
      end

      context "with invalid ip" do
         it "gets a not found error" do
          editors = {editores: {
            codDisciplina: "RM404",
            editores: User.where(username: %w(user3 user4)).map(&:cpf)
          }}
          post "/api/v1/load/curriculum_units/editors", editors, "REMOTE_ADDR" => "127.0.0.2"
          response.status.should eq(404)
        end
      end

    end # editors

  end # .curriculum_units

  describe ".groups" do

    describe "/" do

      context "with valid ip" do # ip is included on list of ips with access

        context "and new semester" do
          let!(:json_data){ {turmas: {ano: "2014", periodo: "2", codDisciplina: "RM302", codigo: "T01", codGraduacao: "109",
              dtInicio: Date.current + 1.day, dtFim: Date.current + 6.months, professores: ["21569104646", "21872285848", "31877336203"]
              }} }

          subject{ -> {
            post "/api/v1/load/groups", json_data}
          }

          it { 
            should change(Semester,:count).by(1) 
            Semester.last.offer_schedule.start_date.to_date.should eq((Date.current + 1.day).to_date)
            Semester.last.offer_schedule.end_date.to_date.should eq((Date.current + 6.months).to_date)
          }
          it { 
            should change(Offer,:count).by(1) 
            Offer.last.period_schedule.should eq(nil)
          }
          it { should change(Group,:count).by(1) }
          it { should change(Allocation,:count).by(3) }

          it {
            post "/api/v1/load/groups", json_data
            response.status.should eq(201) # created
            response.body.should == {ok: :ok}.to_json
          }
        end

        context "and new semester but missing group params" do # transaction must undo all changes
          let!(:json_data){ {turmas: {ano: "2014", periodo: "2", codDisciplina: "RM302", codGraduacao: "109", # missing code
              dtInicio: Date.current + 1.day, dtFim: Date.current + 6.months, professores: ["21569104646", "21872285848", "31877336203"]
              }} }

          subject{ -> {
            post "/api/v1/load/groups", json_data}
          }

          # something happened, so undo all changes and nothing is created
          it { should change(Semester,:count).by(0) }
          it { should change(Offer,:count).by(0) }
          it { should change(Group,:count).by(0) }
          it { should change(Allocation,:count).by(0) }

          it {
            post "/api/v1/load/groups", json_data
            response.status.should eq(422)
          }
        end

        context "and dates smaller then today" do
          let!(:json_data){ {turmas: {ano: "2014", periodo: "2", codDisciplina: "RM302", codigo: "T01", codGraduacao: "109",
              dtInicio: Date.current - 1.month, dtFim: Date.current + 6.months, professores: ["21569104646", "21872285848", "31877336203"]
              }} }

          subject{ -> { 
            post "/api/v1/load/groups", json_data} 
          }

          it { 
            should change(Semester,:count).by(1) 
            Semester.last.offer_schedule.start_date.to_date.should eq((Date.current - 1.month).to_date)
            Semester.last.offer_schedule.end_date.to_date.should eq((Date.current + 6.months).to_date)
          }
          it { 
            should change(Offer,:count).by(1) 
            Offer.last.period_schedule.should eq(nil)
          }
          it { should change(Group,:count).by(1) }
          it { should change(Allocation,:count).by(3) }

          it {
            post "/api/v1/load/groups", json_data
            response.status.should eq(201) # created
            response.body.should == {ok: :ok}.to_json
          }
        end

        context "and existing semester" do
          let!(:json_data){ {turmas: {ano: "2013", periodo: "1", codDisciplina: "RM404", codigo: "RM0121", codGraduacao: "108",
            dtInicio: Date.current + 1.day, dtFim: Date.current + 6.months, professores: ["21569104646", "21872285848", "31877336203"]
            }} }

          subject{ -> { 
            post "/api/v1/load/groups", json_data} 
          }

          it { should change(Semester,:count).by(0) }
          it { 
            should change(Offer,:count).by(1) 
            Offer.last.period_schedule.start_date.to_date.should eq((Date.current + 1.day).to_date)
            Offer.last.period_schedule.end_date.to_date.should eq((Date.current + 6.months).to_date)
          }
          it { should change(Group,:count).by(1) }
          it { should change(Allocation,:count).by(3) }

          it {
            post "/api/v1/load/groups", json_data
            response.status.should eq(201) # created
            response.body.should == {ok: :ok}.to_json
          }
        end

        context "and existing offer" do
          let!(:json_data){ {turmas: {ano: "2013", periodo: "1", codDisciplina: "RM414", codigo: "RM0121", codGraduacao: "108",
            dtInicio: Date.current + 1.day, dtFim: Date.current + 6.months, professores: ["21569104646", "21872285848", "31877336203"]
            }} }

          subject{ -> { 
            post "/api/v1/load/groups", json_data} 
          }

          it { should change(Semester,:count).by(0) }
          it { should change(Offer,:count).by(0) }
          it { should change(Group,:count).by(1) }
          it { should change(Allocation,:count).by(3) }

          it {
            post "/api/v1/load/groups", json_data
            response.status.should eq(201) # created
            response.body.should == {ok: :ok}.to_json
          }
        end

        context "and existing group" do
          let!(:json_data){ {turmas: {ano: "2011", periodo: "1", codDisciplina: "RM301", codigo: "QM-MAR", codGraduacao: "109",
            dtInicio: Date.current + 1.day, dtFim: Date.current + 6.months, professores: ["21569104646", "21872285848", "31877336203"]
            }} }

          subject{ -> { 
            post "/api/v1/load/groups", json_data} 
          }

          it { should change(Semester,:count).by(0) }
          it { should change(Offer,:count).by(0) }
          it { should change(Group,:count).by(0) }
          it { should change(Allocation,:count).by(3) }

          it {
            post "/api/v1/load/groups", json_data
            response.status.should eq(201) # created
            response.body.should == {ok: :ok}.to_json
          }
        end

        context "and existing group removing previous professor" do
          let!(:json_data){ {turmas: {ano: "2011", periodo: "1", codDisciplina: "RM301", codigo: "QM-CAU", codGraduacao: "109",
            dtInicio: Date.current + 1.day, dtFim: Date.current + 6.months, professores: ["21569104646", "31877336203"] # prof já está alocado, ele deve ser removido
            }} }

          subject{ -> { 
            post "/api/v1/load/groups", json_data} 
          }

          it { should change(Semester,:count).by(0) }
          it { should change(Offer,:count).by(0) }
          it { should change(Group,:count).by(0) }
          it { should change(Allocation,:count).by(1) } # has one, two were added, so the difference is 1
          it { should change(User.find_by_cpf("21872285848").allocations,:count).by(-1) } # remove existent allocation if user it isn't on cpf list

          it {
            post "/api/v1/load/groups", json_data
            response.status.should eq(201) # created
            response.body.should == {ok: :ok}.to_json
          }
        end

        context "and non existing uc" do
          let!(:json_data){ {turmas: {ano: "2011", periodo: "1", codDisciplina: "UC01", codigo: "QM-MAR", codGraduacao: "109",
            dtInicio: Date.current + 1.day, dtFim: Date.current + 6.months, professores: ["21569104646", "21872285848", "31877336203"]
            }} }

          subject{ -> { 
            post "/api/v1/load/groups", json_data} 
          }

          it { should change(Semester,:count).by(0) }
          it { should change(Offer,:count).by(0) }
          it { should change(Group,:count).by(0) }
          it { should change(Allocation,:count).by(0) }

          it {
            post "/api/v1/load/groups", json_data
            response.status.should eq(404)
          }
        end

      end

      context "with invalid ip" do # ip isn't included on list of ips with access
        it "gets a not found error" do
          json_data = {turmas: {ano: "2013", periodo: "1", codDisciplina: "RM404", codigo: "RM0121", codGraduacao: "108",
            dtInicio: Date.current + 1.day, dtFim: Date.current + 6.months, professores: ["21569104646", "21872285848", "31877336203"]
            }}
          post "/api/v1/load/groups", json_data, "REMOTE_ADDR" => "127.0.0.2"
          response.status.should eq(404)
        end
      end

    end # groups

    describe "enrollments" do

      context "with valid ip" do

        context 'and list of existing groups' do 
          let!(:json_data){
            { matriculas: {cpf: "11016853521", turmas: [ # user3
              {periodo: "1", ano: "2011", codigo: "QM-CAU", codDisciplina: "RM301", codGraduacao: "109"},
              {periodo: "1", ano: "2011", codigo: "QM-MAR", codDisciplina: "RM301", codGraduacao: "109"},
              {periodo: "1", ano: "2011", codigo: "TL-FOR", codDisciplina: "RM301", codGraduacao: "109"},
              {periodo: "1", ano: "2011", codigo: "TL-FOR", codDisciplina: "RM301", codGraduacao: "109"} # repetido propositalmente
            ]}}
          }

          it {
            expect{
              post "/api/v1/load/groups/enrollments", json_data

              response.status.should eq(201)
              response.body.should == {ok: :ok}.to_json
            }.to change{Allocation.count}.by(3)
          }
        end

         context 'and list of existing groups and cancelling allocation' do 
          let!(:json_data){
            { matriculas: {cpf: "32305605153", turmas: [ # aluno1
              {periodo: "1", ano: "2011", codigo: "QM-MAR", codDisciplina: "RM301", codGraduacao: "109"},
              {periodo: "1", ano: "2011", codigo: "QM-MAR", codDisciplina: "RM301", codGraduacao: "78"} # ignorar código de graduação 78
            ]}}
          }
          let!(:user){User.find_by_cpf("32305605153")}
          let!(:user_allocations){user.allocations.where(status: 1, profile_id: 1)}

          subject{ -> {
            post "/api/v1/load/groups/enrollments", json_data}
          }

          it { should change(user.allocations,:count).by(1) } # add one allocation
          # should change by - (the number of previous allocations (were canceled) -  the number of new allocations)
          it { should change(user.allocations.where(status: 1, profile_id: 1), :count).by(-(user_allocations.count-1)) } 

          it {
            post "/api/v1/load/groups/enrollments", json_data
            response.status.should eq(201) # created
            response.body.should == {ok: :ok}.to_json
          }
        end
        
        context 'and list of non existing groups' do 
          let!(:json_data){
            { matriculas: {cpf: "11016853521", turmas: [ # user3
              {periodo: "1", ano: "2011", codigo: "T01", codDisciplina: "RM301", codGraduacao: "109"}, # turma não existe
              {periodo: "1", ano: "2011", codigo: "T02", codDisciplina: "RM301", codGraduacao: "109"}, # turma não existe
              {periodo: "1", ano: "2011", codigo: "TL-FOR", codDisciplina: "RM301", codGraduacao: "109"} # turma existe
            ]}}
          }

          it {
            expect{
              post "/api/v1/load/groups/enrollments", json_data

              response.status.should eq(201)
              response.body.should == {ok: :ok}.to_json
            }.to change{Allocation.count}.by(1)
          }
        end

        context 'and non existing uc or course' do 
          let!(:json_data){
            { matriculas: {cpf: "11016853521", turmas: [ # user3
              {periodo: "1", ano: "2011", codigo: "QM-CAU", codDisciplina: "RM301", codGraduacao: "C01"}, # uc não existe
              {periodo: "1", ano: "2011", codigo: "QM-MAR", codDisciplina: "UC01", codGraduacao: "109"}, # curso não existe
              {periodo: "1", ano: "2011", codigo: "TL-FOR", codDisciplina: "RM301", codGraduacao: "109"} # turma existe
            ]}}
          }

          it {
            expect{
              post "/api/v1/load/groups/enrollments", json_data

              response.status.should eq(201)
              response.body.should == {ok: :ok}.to_json
            }.to change{Allocation.count}.by(1)
          }
        end

        context 'and non existing user' do 
          let!(:json_data){
            { matriculas: {cpf: "cpf", turmas: [ # cpf inválido / usuário não encontrado
              {periodo: "1", ano: "2011", codigo: "QM-CAU", codDisciplina: "RM301", codGraduacao: "109"},
              {periodo: "1", ano: "2011", codigo: "QM-MAR", codDisciplina: "RM301", codGraduacao: "109"},
              {periodo: "1", ano: "2011", codigo: "TL-FOR", codDisciplina: "RM301", codGraduacao: "109"}
            ]}}
          }

          it {
            expect{
              post "/api/v1/load/groups/enrollments", json_data

              response.status.should eq(404)
            }.to change{Allocation.count}.by(0)
          }
        end

      end

      context "with invalid ip" do
        it "gets a not found error" do
          json_data = { matriculas: {cpf: "11016853521", turmas: [ # user3
                        {periodo: "1", ano: "2011", codigo: "QM-CAU", codDisciplina: "RM301", codGraduacao: "109"}
                     ]}}
          post "/api/v1/load/groups/enrollments", json_data, "REMOTE_ADDR" => "127.0.0.2"
          response.status.should eq(404)
        end
      end

    end # enrollments

    describe ".allocations" do
      describe "block_profile" do

        context "with valid ip" do

          context 'and list of existing groups' do 
            let!(:json_data){ # user: prof, profile: tutor a distância
              { allocation: {cpf: "21872285848", perfil: 1, turma: 
                {periodo: "1", ano: "2011", codigo: "QM-CAU", codDisciplina: "RM301", codGraduacao: "109"}
              }}
            }

            it {
              expect{
                post "/api/v1/load/allocations/block_profile", json_data

                response.status.should eq(201)
                response.body.should == {ok: :ok}.to_json
              }.to change{Allocation.where(status: 2).count}.by(1) #alocações com status cancelado aumentam de número
            }
          end

          context 'and list of non existing groups' do 
            let!(:json_data){ # user: prof, profile: tutor a distância
              { allocation: {cpf: "21872285848", perfil: 1, turma:
                {periodo: "1", ano: "2011", codigo: "T02", codDisciplina: "RM301", codGraduacao: "109"}  # turma não existe
              }}
            }

            it {
              expect{
                post "/api/v1/load/allocations/block_profile", json_data

                response.status.should eq(201)
                response.body.should == {ok: :ok}.to_json
              }.to change{Allocation.where(status: 2).count}.by(0)
            }
          end

          context 'and non existing course' do 
            let!(:json_data){ # user: prof, profile: tutor a distância
              { allocation: {cpf: "21872285848", perfil: 1, turma:
                {periodo: "1", ano: "2011", codigo: "IL-FOR", codDisciplina: "RM404", codGraduacao: "C01"}, # curso não existe
              }}
            }

            it {
              expect{
                post "/api/v1/load/allocations/block_profile", json_data

                response.status.should eq(201)
                response.body.should == {ok: :ok}.to_json
              }.to change{Allocation.where(status: 2).count}.by(0)
            }
          end

          context 'and non existing uc' do 
            let!(:json_data){ # user: prof, profile: tutor a distância
              { allocation: {cpf: "21872285848", perfil: 1, turma:
                {periodo: "1", ano: "2011", codigo: "QM-CAU", codDisciplina: "UC01", codGraduacao: "109"}  # uc não existe
              }}
            }
          
            it {
              expect{
                post "/api/v1/load/allocations/block_profile", json_data

                response.status.should eq(201)
                response.body.should == {ok: :ok}.to_json
              }.to change{Allocation.where(status: 2).count}.by(0)
            }
          end

          context 'and non existing user' do 
            let!(:json_data){ # cpf inválido
              { allocation: {cpf: "cpf", perfil: 1, turma:
                {periodo: "1", ano: "2011", codigo: "QM-CAU", codDisciplina: "RM301", codGraduacao: "109"}
              }}
            }

            it {
              expect{
                post "/api/v1/load/allocations/block_profile", json_data

                response.status.should eq(404)
              }.to change{Allocation.where(status: 2).count}.by(0)
            }
          end

        end

        context "with invalid ip" do
          it "gets a not found error" do
            json_data = # user: prof, profile: tutor a distância
              { allocation: {cpf: "21872285848", perfil: 1, turma: 
                {periodo: "1", ano: "2011", codigo: "QM-CAU", codDisciplina: "RM301", codGraduacao: "109"}
              }}
            post "/api/v1/load/groups/enrollments", json_data, "REMOTE_ADDR" => "127.0.0.2"
            response.status.should eq(404)
          end
        end


      end

    end


  end

end