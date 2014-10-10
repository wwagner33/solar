require "spec_helper"

describe "Integrations" do

  fixtures :all

  describe ".events" do

    describe "/" do

      context "with valid ip" do
        context "and existing groups" do
          it {
            events = {
              CodigoDisciplina: "RM301", CodigoCurso: "109", Periodo: "2011.1", DataInserida: {
                Tipo: 1, Data: "2014-11-01", Polo: "Pindamanhangaba", HoraInicio: "10:00", HoraFim: "11:00" },
              Turmas: ["QM-CAU", "TL-FOR", "QM-MAR"]
            }

            expect{
              post "/api/v1/integration/events/", events

              response.status.should eq(201)
              response.body.should == [ {Codigo: "QM-CAU", id: ScheduleEvent.last(3).first.id}, 
                {Codigo: "TL-FOR", id: ScheduleEvent.last(2).first.id}, {Codigo: "QM-MAR", id: ScheduleEvent.last.id}
              ].to_json
            }.to change{ScheduleEvent.where(integrated: true).count}.by(3)
          }
        end

        context "and not existing group" do
          it {
            events = {
              CodigoDisciplina: "RM301", CodigoCurso: "109", Periodo: "2011.1", DataInserida: {
                Tipo: 1, Data: "2014-11-01", Polo: "Pindamanhangaba", HoraInicio: "10:00", HoraFim: "11:00" },
              Turmas: ["T01", "TL-FOR", "QM-MAR"]
            }

            expect{
              post "/api/v1/integration/events/", events

              response.status.should eq(422)
            }.to change{ScheduleEvent.count}.by(0)
          }
        end

        context "and missing event params" do
          it {
            events = {
              CodigoDisciplina: "RM301", CodigoCurso: "109", Periodo: "2011.1", DataInserida: {
                Tipo: 1, Polo: "Pindamanhangaba", HoraInicio: "10:00", HoraFim: "11:00" },
              Turmas: ["QM-CAU", "TL-FOR", "QM-MAR"]
            }

            expect{
              post "/api/v1/integration/events/", events

              response.status.should eq(400)
            }.to change{ScheduleEvent.count}.by(0)
          }
        end

      end # with valid ip

      context "with invalid ip" do
        it "gets a not found error" do
          events = {
            CodigoDisciplina: "RM301", CodigoCurso: "109", Periodo: "2011.1", DataInserida: {
              Tipo: 1, Data: "2014-11-01", Polo: "Pindamanhangaba", HoraInicio: "10:00", HoraFim: "11:00" },
            Turmas: ["QM-CAU", "TL-FOR", "QM-MAR"]
          }

          expect{
            post "/api/v1/integration/events/", events, "REMOTE_ADDR" => "127.0.0.2"
            response.status.should eq(404)
            }.to change{ScheduleEvent.count}.by(0)
        end
      end

    end # /

    describe ":ids" do

      context "with valid ip" do
        context "and existing events" do
          it {
            expect{
              delete "/api/v1/integration/events/2,3"

              response.status.should eq(200)
              response.body.should == {ok: :ok}.to_json
            }.to change{ScheduleEvent.count}.by(-2)
          }
        end

        context "and non existing events" do
          it {
            expect{
              delete "/api/v1/integration/events/122"

              response.status.should eq(200)
              response.body.should == {ok: :ok}.to_json
            }.to change{ScheduleEvent.count}.by(0)
          }
        end

        context "and missing params" do
          it {
            expect{
              delete "/api/v1/integration/events/"

              response.status.should eq(405)
            }.to change{ScheduleEvent.count}.by(0)
          }
        end        
      end # valid ip

      context "with invalid ip" do
        it "gets a not found error" do
          expect{
            delete "/api/v1/integration/events/2,3", nil, "REMOTE_ADDR" => "127.0.0.2"
            response.status.should eq(404)
            }.to change{ScheduleEvent.count}.by(0)
        end
      end

    end # :ids

  end # .events

  describe ".event" do

    describe "put :id" do

      context "with valid ip" do
        context "and existing event" do
          it {
            event = { Data: (Date.today - 1.day).to_s, HoraInicio: "10:00", HoraFim: "11:00" }

            expect{
              put "/api/v1/integration/event/3", event
              response.status.should eq(200)
              response.body.should == {ok: :ok}.to_json
              expect(ScheduleEvent.find(3).as_json).to eq({
                description: "Encontro Presencial marcado para esse período", # não é alterado
                end_hour: "11:00",
                id: 3,
                integrated: true,
                place: "Polo A", # não é alterado
                schedule_id: 27,
                start_hour: "10:00",
                title: "Encontro Presencial", # não é alterado
                type_event: 2 # não é alterado
              }.as_json)
            }.to change{ScheduleEvent.count}.by(0)
          }
        end

        context "and non existing event" do
          it {
            event = { Data: (Date.today - 1.day).to_s, HoraInicio: "10:00", HoraFim: "11:00" }

            expect{
              put "/api/v1/integration/event/333", event
              response.status.should eq(422)
            }.to change{ScheduleEvent.count}.by(0)
          }
        end

        context "and missing params" do
          it {
            event = { Data: (Date.today - 1.day).to_s, HoraInicio: "10:00" }

            expect{
              put "/api/v1/integration/event/3", event
              response.status.should eq(400)
            }.to change{ScheduleEvent.count}.by(0)
          }
        end
      end # valid ip

      context "with invalid ip" do
        it "gets a not found error" do
          event = { Data: (Date.today - 1.day).to_s, HoraInicio: "10:00", HoraFim: "11:00" }

          expect{
            put "/api/v1/integration/event/3", event, "REMOTE_ADDR" => "127.0.0.2"
            response.status.should eq(404)
            }.to change{ScheduleEvent.count}.by(0)
        end
      end

    end # PUT :id

  end # .event


  describe ".user" do

    describe "/" do

      context "with valid ip" do
        context "and valid data" do
          it {
            user = { name: "Usuario novo", nick: "usuario novo", cpf: "69278278203", birthdate: "1980-10-17", gender: true, email: "email@email.com" }

            expect{
              post "/api/v1/integration/user/", user

              response.status.should eq(201)
            }.to change{User.where(cpf: "69278278203").count}.by(1)
          }
        end

        context "and invalid data" do
          it {
            user = { name: "Usuario novo", nick: "usuario novo", cpf: "69278278203", birthdate: "1980-10-17", gender: true } # missing email

            expect{
              post "/api/v1/integration/user/", user

              response.status.should eq(400)
            }.to change{User.where(cpf: "69278278203").count}.by(0)
          }
        end
      end

      context "with invalid ip" do
        it "gets a not found error" do
          user = { name: "Usuario novo", nick: "usuario novo", cpf: "69278278203", birthdate: "1980-10-17", gender: true, email: "email@email.com" }

          expect{
            post "/api/v1/integration/user/", user, "REMOTE_ADDR" => "127.0.0.2"
            response.status.should eq(404)
          }.to change{User.where(cpf: "69278278203").count}.by(0)
        end
      end

    end

  end # .user

  describe ".groups" do

    describe "merge" do

      context "with valid ip" do

        # transfer content from QM-CAU to QM-MAR
        context 'do merge' do
          let!(:json_data){ { 
            main_group: "QM-MAR",
            secundary_groups: ["QM-CAU"],
            course: "109",
            curriculum_unit: "RM301",
            period: "2011.1",
            type_merge: true
          } }

          subject{ -> { put "/api/v1/integration/groups/merge/", json_data } } 

          it { should change(AcademicAllocation.where(allocation_tag_id: 11, academic_tool_type: "Discussion"),:count).by(4) }
          it { should change(Post,:count).by(4) }
          it { should change(AcademicAllocation.where(allocation_tag_id: 11, academic_tool_type: "Assignment"),:count).by(9) }
          it { should change(SentAssignment,:count).by(5) }
          it { should change(AssignmentFile,:count).by(4) }
          it { should change(AssignmentComment,:count).by(3) }
          it { should change(CommentFile,:count).by(1) }
          it { should change(GroupAssignment,:count).by(6) }
          it { should change(GroupParticipant,:count).by(9) }
          it { should change(AcademicAllocation.where(allocation_tag_id: 11, academic_tool_type: "ChatRoom"),:count).by(3) }
          it { should change(ChatMessage,:count).by(5) }
          it { should change(PublicFile,:count).by(1) }
          it { should change(Message,:count).by(1) }
          it { should change(LogAction,:count).by(1) }
          it { should change(Merge,:count).by(1) }
          it { should change(Group.where(status: false),:count).by(1) }

          it {
            put "/api/v1/integration/groups/merge/", json_data
            response.status.should eq(200)
            response.body.should == {ok: :ok}.to_json
          }
        end
      
        # transfer content from QM-MAR to QM-CAU (QM-MAR only has one post and one sent_assignment different from QM-CAU)
        context 'undo merge' do
          let!(:json_data){ { 
            main_group: "QM-MAR",
            secundary_groups: ["QM-CAU"],
            course: "109",
            curriculum_unit: "RM301",
            period: "2011.1",
            type_merge: false
          } }

          subject{ -> { put "/api/v1/integration/groups/merge/", json_data } } 

          # QM-CAU loses all content it have to receive QM-MAR's content
          it { should change(AcademicAllocation.where(allocation_tag_id: 3, academic_tool_type: "Discussion"),:count).by(0) }
          it { should change(Post,:count).by(-3) } # it has 4, received 1
          it { should change(AcademicAllocation.where(allocation_tag_id: 3, academic_tool_type: "Assignment"),:count).by(0) }
          it { should change(SentAssignment,:count).by(-3) } # it has 4, received 1
          it { should change(AssignmentFile,:count).by(-4) }
          it { should change(AssignmentComment,:count).by(-2) }
          it { should change(CommentFile,:count).by(-1) }
          it { should change(GroupAssignment,:count).by(-5) }
          it { should change(GroupParticipant,:count).by(-8) }
          it { should change(AcademicAllocation.where(allocation_tag_id: 3, academic_tool_type: "ChatRoom"),:count).by(0) }
          it { should change(ChatMessage,:count).by(-5) }
          it { should change(PublicFile,:count).by(0) }
          it { should change(Message,:count).by(0) }
          it { should change(LogAction,:count).by(1) }
          it { should change(Merge,:count).by(1) }
          it { should change(Group.where(status: false),:count).by(0) }

          it {
            put "/api/v1/integration/groups/merge/", json_data
            response.status.should eq(200)
            response.body.should == {ok: :ok}.to_json
          }
        end 
      end

      context 'missing params' do
        let!(:json_data){ { 
          main_group: "QM-MAR",
          course: "109",
          curriculum_unit: "RM301",
          period: "2011.1",
          type_merge: true
        } }

        subject{ -> { put "/api/v1/integration/groups/merge/", json_data } } 

        it { should change(AcademicAllocation.where(allocation_tag_id: 11, academic_tool_type: "Discussion"),:count).by(0) }
        it { should change(Post,:count).by(0) }
        it { should change(AcademicAllocation.where(allocation_tag_id: 11, academic_tool_type: "Assignment"),:count).by(0) }
        it { should change(SentAssignment,:count).by(0) }
        it { should change(AssignmentFile,:count).by(0) }
        it { should change(AssignmentComment,:count).by(0) }
        it { should change(CommentFile,:count).by(0) }
        it { should change(GroupAssignment,:count).by(0) }
        it { should change(GroupParticipant,:count).by(0) }
        it { should change(AcademicAllocation.where(allocation_tag_id: 11, academic_tool_type: "ChatRoom"),:count).by(0) }
        it { should change(ChatMessage,:count).by(0) }
        it { should change(PublicFile,:count).by(0) }
        it { should change(Message,:count).by(0) }
        it { should change(LogAction,:count).by(0) }
        it { should change(Merge,:count).by(0) }
        it { should change(Group.where(status: false),:count).by(0) }

        it {
          put "/api/v1/integration/groups/merge/", json_data
          response.status.should eq(400)
        }
      end

      context 'group doesnt exist' do
        let!(:json_data){ { 
          main_group: "QM-MAR",
          secundary_groups: ["QM-0"],
          course: "109",
          curriculum_unit: "RM301",
          period: "2011.1",
          type_merge: true
        } }

        subject{ -> { put "/api/v1/integration/groups/merge/", json_data } } 

        it { should change(AcademicAllocation.where(allocation_tag_id: 11, academic_tool_type: "Discussion"),:count).by(0) }
        it { should change(Post,:count).by(0) }
        it { should change(AcademicAllocation.where(allocation_tag_id: 11, academic_tool_type: "Assignment"),:count).by(0) }
        it { should change(SentAssignment,:count).by(0) }
        it { should change(AssignmentFile,:count).by(0) }
        it { should change(AssignmentComment,:count).by(0) }
        it { should change(CommentFile,:count).by(0) }
        it { should change(GroupAssignment,:count).by(0) }
        it { should change(GroupParticipant,:count).by(0) }
        it { should change(AcademicAllocation.where(allocation_tag_id: 11, academic_tool_type: "ChatRoom"),:count).by(0) }
        it { should change(ChatMessage,:count).by(0) }
        it { should change(PublicFile,:count).by(0) }
        it { should change(Message,:count).by(0) }
        it { should change(LogAction,:count).by(0) }
        it { should change(Merge,:count).by(0) }
        it { should change(Group.where(status: false),:count).by(0) }

        it {
          put "/api/v1/integration/groups/merge/", json_data
          response.status.should eq(404) # not found
        }
      end

      context "with invalid ip" do
        let!(:json_data){ { 
            main_group: "QM-MAR",
            secundary_groups: ["QM-CAU"],
            course: "109",
            curriculum_unit: "RM301",
            period: "2011.1",
            type_merge: true
          } }

        it "gets a not found error" do
          put "/api/v1/integration/groups/merge/", json_data, "REMOTE_ADDR" => "127.0.0.2"
          response.status.should eq(404)
        end
      end

    end #merge

  end #groups

  describe "bla" do
   describe ".course" do

    describe "post" do

      context "with valid ip" do

        context 'create course' do
          let!(:json_data){ { 
            name: "Curso 01",
            code: "C01"
          } }

          subject{ -> { post "/api/v1/integration/course", json_data } } 

          it { should change(Course,:count).by(1) }

          it {
            post "/api/v1/integration/course", json_data
            response.status.should eq(201)
            response.body.should == {id: Course.find_by_code("C01").id}.to_json
          }
        end

      end

    end # post

  end # .course

  describe ".curriculum_unit" do

    describe "post" do

      context "with valid ip" do

        context 'create curriculum_unit' do
          let!(:json_data){ { 
            name: "UC 01",
            code: "UC01",
            curriculum_unit_type_id: 1
          } }

          subject{ -> { post "/api/v1/integration/curriculum_unit", json_data } } 

          it { should change(CurriculumUnit,:count).by(1) }

          it {
            post "/api/v1/integration/curriculum_unit", json_data
            response.status.should eq(201)
            response.body.should == {id: CurriculumUnit.find_by_code("UC01").id, course_id: nil}.to_json
          }
        end

        context 'create curriculum_unit tipo livre' do
          let!(:json_data){ { 
            name: "UC 01",
            code: "UC01",
            curriculum_unit_type_id: 3
          } }

          subject{ -> { post "/api/v1/integration/curriculum_unit", json_data } } 

          it { should change(Course,:count).by(1) }
          it { should change(CurriculumUnit,:count).by(1) }

          it {
            post "/api/v1/integration/curriculum_unit", json_data
            response.status.should eq(201)
            response.body.should == {id: CurriculumUnit.find_by_code("UC01").id, course_id: Course.find_by_code("UC01").id}.to_json
          }
        end

      end

    end # post

  end # .curriculum_unit

  describe ".offer" do

    describe "post" do

      context "with valid ip" do

        context 'create offer with new semester' do
          let!(:json_data){ { 
            name: "2014",
            offer_start: Date.today - 1.month,
            offer_end: Date.today + 1.month,
            curriculum_unit_id: 3, 
            course_id: 2
          } }

          subject{ -> { post "/api/v1/integration/offer", json_data } } 

          it { should change(Semester,:count).by(1) }
          it { should change(Schedule,:count).by(2) }
          it { should change(Offer,:count).by(1) }

          it {
            post "/api/v1/integration/offer", json_data
            response.status.should eq(201)
            response.body.should == {id: Offer.last.id}.to_json
          }
        end

        context 'create offer with existing semester and same dates' do
          let!(:json_data){ { 
            name: "2011.1",
            offer_start: '2011-03-10',
            offer_end: '2021-12-01',
            enrollment_start: '2011-01-01',
            enrollment_end: '2021-03-02',
            curriculum_unit_id: 1,
            course_id: 1
          } }

          subject{ -> { post "/api/v1/integration/offer", json_data } } 

          it { should change(Semester,:count).by(0) }
          it { should change(Schedule,:count).by(0) }
          it { should change(Offer,:count).by(1) }

          it {
            post "/api/v1/integration/offer", json_data
            response.status.should eq(201)
            response.body.should == {id: Offer.last.id}.to_json
          }
        end

        context 'create offer with existing semester and same offer dates' do
          let!(:json_data){ { 
            name: "2011.1",
            offer_start: '2011-03-10',
            offer_end: '2021-12-01',
            curriculum_unit_id: 1,
            course_id: 1
          } }

          subject{ -> { post "/api/v1/integration/offer", json_data } } 

          it { should change(Semester,:count).by(0) }
          it { should change(Schedule,:count).by(1) }
          it { should change(Offer,:count).by(1) }

          it {
            post "/api/v1/integration/offer", json_data
            response.status.should eq(201)
            response.body.should == {id: Offer.last.id}.to_json
          }
        end

        context 'create offer with existing semester and different dates' do
          let!(:json_data){ { 
            name: "2011.1",
            offer_start: Date.today,
            offer_end: Date.today+4.month,
            curriculum_unit_id: 1,
            course_id: 1
          } }

          subject{ -> { post "/api/v1/integration/offer", json_data } } 

          it { should change(Semester,:count).by(0) }
          it { should change(Schedule,:count).by(2) }
          it { should change(Offer,:count).by(1) }

          it {
            post "/api/v1/integration/offer", json_data
            response.status.should eq(201)
            response.body.should == {id: Offer.last.id}.to_json
            Offer.last.period_schedule.start_date.to_date.should eq(Date.today.to_date)
          }
        end
        
      end

    end # post

  end # .offer
end

end