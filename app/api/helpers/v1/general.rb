module V1::General

  ## only webserver can access
  def verify_ip_access!
    raise ActiveRecord::RecordNotFound unless YAML::load(File.open('config/modulo_academico.yml'))[Rails.env.to_s]['verified_addresses'].include?(request.env['REMOTE_ADDR'])
  end

  def verify_or_create_user(cpf)
    user = User.find_by_cpf(cpf.delete('.').delete('-'))
    return user if user

    user = User.new cpf: cpf
    user.connect_and_validates_user if user.can_synchronize?

    raise ActiveRecord::RecordNotFound unless user.valid? and not(user.new_record?)

    user
  end

  # def get_users(cpfs)
  #   users = []
  #   cpfs.each do |cpf|
  #     users << verify_or_create_user(cpf)
  #   end
  #   users
  # end

  def get_destination(curriculum_unit_code, course_code, code, semester)
    case
      when not(code.blank?)
        get_group_by_codes(curriculum_unit_code, course_code, code, semester)
      when not(semester.blank?)
        get_offer(curriculum_unit_code, course_code, semester)
      when not(curriculum_unit_code.blank?)
        CurriculumUnit.find_by_code(curriculum_unit_code)
      when not(course_code.blank?)
        Course.find_by_code(course_code)
    end
  end 

end