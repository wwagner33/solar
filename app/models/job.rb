class Job

  AMOUNT = YAML::load(File.open('config/mailer.yml'))['mass_emails']['max_amount'] rescue nil
  SCHEDULEDTIME = YAML::load(File.open('config/mailer.yml'))['mass_emails']['scheduled_time'] rescue nil
  DELAYEDJOB = YAML::load(File.open('config/global.yml'))['run_delayed_job'] rescue nil

  # returns a list of jobs that wasnt sent and still could
  # sums amount to be sent with the amount sent on the last SCHEDULEDTIME minutes
  # change status of jobs that will be send
  # maximum amount of jobs collected is AMOUNT
  def self.select_and_update_status_jobs_not_send
    unless AMOUNT.nil? || SCHEDULEDTIME.nil?
      Delayed::Job.find_by_sql <<-SQL
          WITH RECURSIVE delayed_job(id, amount, total) AS (
            SELECT
              id, amount,
              (SELECT SUM(dj2.amount) +
              (SELECT CASE WHEN (SUM(dj.amount) IS NULL OR SUM(dj.amount)<1) THEN 0 ELSE SUM(dj.amount) END FROM delayed_jobs dj WHERE dj.status = true AND dj.created_at >= (now() - interval '#{SCHEDULEDTIME} minutes'))
              FROM delayed_jobs dj2 WHERE dj2.id <= dj1.id AND dj2.status = false) AS total
            FROM delayed_jobs dj1 WHERE dj1.status = false ORDER BY id ASC
          )
          UPDATE delayed_jobs SET status = true WHERE id IN (SELECT id from delayed_job WHERE total<=#{AMOUNT}) RETURNING *;
      SQL
    else
      []
    end
  end

  def self.delete_jobs
    unless SCHEDULEDTIME.nil?
      Delayed::Job.where("status = true AND created_at < (now() - interval '#{SCHEDULEDTIME} minute')").delete_all
    end
  end

  def self.send_mass_email(emails, subject, new_msg_template, files=[], email=nil)
    unless AMOUNT.nil?
      # Thread.new do
      #   ActiveRecord::Base.forbid_implicit_checkout_for_thread!
      #   ActiveRecord::Base.connection_pool.with_connection do
          emails_in_jobs = emails.in_groups_of(AMOUNT, false).to_a rescue []

          emails_in_jobs.each do |e|
            job = Notifier.delay.send_mail(e, subject, new_msg_template, files, email)
            job.amount = e.count
            job.save!

          end
          Job.job_send_mail unless DELAYEDJOB.blank?
        end
    #   end
    # end
  end

  def self.send_mass_email_post(emails, subject, post_id, info, discussion_name)
    unless AMOUNT.nil?
      # Thread.new do
      #   ActiveRecord::Base.forbid_implicit_checkout_for_thread!
      #   ActiveRecord::Base.connection_pool.with_connection do
          emails_in_jobs = emails.in_groups_of(AMOUNT, false).to_a rescue []

          emails_in_jobs.each do |e|
            job = Notifier.delay.post(e, subject, post_id, info, discussion_name)
            job.amount = e.count
            job.save!

          end
          Job.job_send_mail unless DELAYEDJOB.blank?
        end
    #   end
    # end
  end

  def self.send_mass_email_exam(emails, subject, exam, acu, grade)
    unless AMOUNT.nil?
      # Thread.new do
      #   ActiveRecord::Base.forbid_implicit_checkout_for_thread!
      #   ActiveRecord::Base.connection_pool.with_connection do
          emails_in_jobs = emails.in_groups_of(AMOUNT, false).to_a rescue []

          emails_in_jobs.each do |e|
            job = Notifier.delay.exam(e, subject, exam, acu, grade)
            job.amount = e.count
            job.save!

          end
          Job.job_send_mail unless DELAYEDJOB.blank?
        end
    #   end
    # end
  end

  # send email and save a clone at database
  # clone exists during SCHEDULEDTIME minutes and then "delete_jobs" remove it
  def self.job_send_mail
    jobs = Job.select_and_update_status_jobs_not_send
    jobs.each do |job|
      clone_job = job.dup
      Delayed::Worker.new.run(job)
      clone_job.save!
    end

    Job.delete_jobs
  end

end
