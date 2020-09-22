
class Notifier < ActionMailer::Base

  default YAML::load(File.open('config/mailer.yml'))['default_sender']

  def send_mail(recipients, subject, message, files, from = nil)
    files.each do |file|
      attachments[file.attachment_file_name] = File.read(file.attachment.path)
    end

    config_mail = { bcc: recipients, subject: "[SOLAR] #{subject}" }
    config_mail[:reply_to] = from unless from.nil?

    mail(config_mail) do |format|
      format.text { render text: message }
      format.html { render text: message }
    end
  end

  def enrollment_accepted(recipient, group)
    @group = group
    mail(bcc: recipient,
         subject: t(:subject, scope: [:notifier, :enrollment_accepted]))
  end

  def new_user(user, password)
    @user, @password = user, password
    mail(to: @user.email,
         subject: "[SOLAR] Novo Cadastro")
  end

  def enroll_user(user, allocation_tag, token=nil, password=nil)
    @user, @token, @password = user, token, password
    @allocation_tag = allocation_tag.info

    mail(to: @user.email,
         subject: "[SOLAR] Matrícula")
  end

  def change_user(user, token=nil, password=nil, username_changed=nil, password_changed=nil, removed_integration=nil, changed_data=[])
    @user, @token, @password = user, token, password
    @username_changed, @password_changed = username_changed, password_changed
    @removed_integration = removed_integration

    @changed_data = []
    changed_data.each do |data|
      @changed_data << t("activerecord.attributes.user.#{data.to_s}")
    end

    mail(to: @user.email,
         subject: "[SOLAR] Mudança de dados de acesso")
  end

  def groups_disabled(emails, groups_codes, offer_info)
    @groups_codes, @offer_info = groups_codes, offer_info
    mail(bcc: emails,
         subject: t("notifier.groups_disabled.subject"))
  end

  def imported_from_private(lesson)
    @lesson = lessson
    mail(to: @lesson.user.email,
         subject: t('notifier.imported_from_private.subject'))
  end

  def post(recipients, subject, post_id, info, discussion_name)
    @post = Post.find(post_id)
    @old_post = @post.parent
    @info = info
    @discussion_name = discussion_name
    @locale = (@old_post.user.personal_configuration.default_locale rescue 'pt_BR')

    mail(bcc: recipients, subject: "[SOLAR] #{subject}")
  end

  def exam(recipients, subject, exam, acu, grade)
    @exam = exam
    @user = acu.user
    @allocation_tag = acu.allocation_tag
    @locale = (@user.personal_configuration.default_locale rescue 'pt_BR')
    @grade = grade

    mail(bcc: recipients, subject: "[SOLAR] #{subject}")
  end

  def notify_exam_content(event, emails, subject)
    @offer_info = event.allocation_tags.first.no_group_info rescue ''
    @groups_codes = event.allocation_tags.map(&:groups).flatten.map(&:code).join(', ') rescue ''
    @event = event
    mail(bcc: emails, subject: "[SOLAR] #{subject}")
  end

end
