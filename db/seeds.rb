# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ :name => 'Chicago' }, { :name => 'Copenhagen' }])
#   Mayor.create(:name => 'Daley', :city => cities.first)

user1 = User.new :login => 'user', :email => 'user@user.com', :name => 'Username', :cpf => '78218921494', :birthdate => '2005-03-02', :gender => true, :address => 'em algum lugar', :address_number => 58, :address_neighborhood => 'bons', :country => 'brazil', :state => 'CE', :city => 'fortaleza', :institution => 'ufc', :zipcode => '60450170'
user1.password = 'user123'
user1.save

courses = Course.create([
    { :name => 'Letras Portugues', :code => 'LLPT' },
    { :name => 'Licenciatura em Quimica', :code => 'LQUIM' }
  ])

curriculum_unit_types = CurriculumUnitType.create([
    { :description => 'Presential Undergraduate Course', :allows_enrollment => TRUE },
    { :description => 'Distance Undergraduate Course', :allows_enrollment => FALSE },
    { :description => 'Free Course', :allows_enrollment => TRUE },
    { :description => 'Extension Course', :allows_enrollment => TRUE },
    { :description => 'Presential Graduate Course', :allows_enrollment => TRUE },
    { :description => 'Distance Graduate Course', :allows_enrollment => FALSE }
  ])

curriculum_units = CurriculumUnit.create([
    {:curriculum_unit_types_id => curriculum_unit_types[2].id, :name => 'Introducao a Linguistica', :code => 'RM404'},
    {:curriculum_unit_types_id => curriculum_unit_types[0].id, :name => 'Teoria da Literatura I', :code => 'RM405'},
    {:curriculum_unit_types_id => curriculum_unit_types[1].id, :name => 'Quimica I', :code => 'RM301'},
    {:curriculum_unit_types_id => curriculum_unit_types[1].id, :name => 'Semipresencial sm nvista', :code => 'TS101'}
  ])

offers = Offer.create([
    {:curriculum_units_id => curriculum_units[2].id, :courses_id => courses[0].id, :semester => '2011.1', :start => '2011-02-01', :end => '2011-03-30'},
    {:curriculum_units_id => curriculum_units[1].id, :courses_id => courses[0].id, :semester => '2011.1', :start => '2011-03-10', :end => '2011-04-01'},
    {:curriculum_units_id => curriculum_units[3].id, :courses_id => courses[1].id, :semester => '2011.1', :start => '2011-03-10', :end => '2011-04-01'}
  ])

enrollments = Enrollment.create([
    {:offers_id => offers[0].id, :start => '2011-01-01', :end => '2011-03-02'},
    {:offers_id => offers[1].id, :start => '2011-01-01', :end => '2011-03-02'},
    {:offers_id => offers[2].id, :start => '2011-01-01', :end => '2011-03-02'}
  ])

groups = Group.create([
    {:offers_id => offers[0].id, :code => 'FOR', :status => TRUE},
    {:offers_id => offers[1].id, :code => 'CAU-A', :status => TRUE},
    {:offers_id => offers[2].id, :code => 'CAU-B', :status => TRUE}
  ])

profiles = Profile.create([
    {:name => 'Aluno', :student => TRUE},
    {:name => 'Prof. Titular', :class_responsible => TRUE},
    {:name => 'Tutor'}
  ])

resources = Resource.create([
  {:controller => 'user', :action => 'create', :description => 'Incluir novos usuarios no sistema'},
  {:controller => 'user', :action => 'update', :description => 'Alteracao dos dados do usuario'},
  {:controller => 'user', :action => 'mysolar', :description => 'Lista dos Portlest/Pagina inicial'},
  {:controller => 'user', :action => 'update_photo', :description => 'Trocar foto'},
  {:controller => 'user', :action => 'pwd_recovery', :description => 'Recuperar Senha'},
  {:controller => 'offer', :action => 'show', :description => 'Visualizacao de ofertas'},
  {:controller => 'offer', :action => 'update', :description => 'Edicao de ofertas'},
  {:controller => 'offer', :action => 'showoffersbyuser', :description => 'Exibe oferta atraves de busca'},
  {:controller => 'group', :action => 'show', :description => 'Visualizar turmas'},
  {:controller => 'group', :action => 'update', :description => 'Editar turmas'}
])

permissions = Permission.create([
  {:profiles_id => profiles[0].id, :resources_id => resources[5].id, :per_id => true},
  {:profiles_id => profiles[0].id, :resources_id => resources[6].id, :per_id => true},
  {:profiles_id => profiles[0].id, :resources_id => resources[7].id, :per_id => true},
  {:profiles_id => profiles[0].id, :resources_id => resources[8].id, :per_id => true},
  {:profiles_id => profiles[0].id, :resources_id => resources[9].id, :per_id => true}
])

allocation_tags = AllocationTag.create([
    {:groups_id => groups[0].id},
    {:groups_id => groups[1].id},
    {:groups_id => groups[2].id},
    {:offers_id => offers[0].id},
    {:offers_id => offers[1].id},
    {:offers_id => offers[2].id},
    {:curriculum_units_id => curriculum_units[0].id},
    {:curriculum_units_id => curriculum_units[1].id}
	])

allocations = Allocation.create([
    {:users_id => user1.id, :allocation_tags_id => allocation_tags[0].id, :profiles_id => profiles[0].id, :status => 1},
    {:users_id => user1.id, :allocation_tags_id => allocation_tags[1].id, :profiles_id => profiles[0].id, :status => 1},
    {:users_id => user1.id, :allocation_tags_id => allocation_tags[2].id, :profiles_id => profiles[0].id, :status => 1},
    {:users_id => user1.id, :allocation_tags_id => allocation_tags[3].id, :profiles_id => profiles[0].id, :status => 1},
    {:users_id => user1.id, :allocation_tags_id => allocation_tags[4].id, :profiles_id => profiles[0].id, :status => 1},
    {:users_id => user1.id, :allocation_tags_id => allocation_tags[5].id, :profiles_id => profiles[0].id, :status => 1},
    {:users_id => user1.id, :allocation_tags_id => allocation_tags[6].id, :profiles_id => profiles[0].id, :status => 1},
    {:users_id => user1.id, :allocation_tags_id => allocation_tags[7].id, :profiles_id => profiles[0].id, :status => 1}
  ])
