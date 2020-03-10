require 'active_support/concern'
require 'bigbluebutton_api'

module Bbb
  extend ActiveSupport::Concern

  included do
    attr_accessor :merge
  end

  def verify_quantity_users( allocation_tags_ids = [])
    query = "(initial_time BETWEEN ? AND ?) OR ((initial_time + (interval '1 minutes')*duration) BETWEEN ? AND ?) OR (? BETWEEN initial_time AND ((initial_time + (interval '1 minutes')*duration))) OR (? BETWEEN initial_time AND ((initial_time + (interval '1 minutes')*duration)))"
    end_time       = initial_time + duration.minutes
    webconferences = Webconference.where(query, initial_time, end_time, initial_time, end_time, initial_time, end_time).to_a
    assignment_webconferences = AssignmentWebconference.where(query, initial_time, end_time, initial_time, end_time, initial_time, end_time).to_a
    webconferences            << self unless self.class == AssignmentWebconference || webconferences.include?(self)
    assignment_webconferences << self unless self.class == Webconference || assignment_webconferences.include?(self)

    unless webconferences.empty? && assignment_webconferences.empty?
      ats      = webconferences.map(&:allocation_tags).flatten.map(&:related).flatten
      ats      << allocation_tags_ids if allocation_tags_ids.any? && !webconferences.include?(self)
      students = 0
      ats.flatten.each do |at|
        allocations = Allocation.find_by_sql <<-SQL
          SELECT COUNT(allocations.id)
          FROM allocations
          JOIN profiles ON profiles.id = allocations.profile_id
          WHERE
            cast( profiles.types & #{Profile_Type_Student} as boolean )
          AND
            allocations.allocation_tag_id = #{at}
          AND
            allocations.status = 1;
        SQL
      students += allocations.first['count'].to_i
      end

      students += assignment_webconferences.map(&:academic_allocation_user).flatten.map(&:users_count).flatten.sum unless assignment_webconferences.empty?

      if students > YAML::load(File.open('config/webconference.yml'))['max_simultaneous_users']
        errors.add(:initial_time, I18n.t("#{self.class.to_s.tableize}.error.limit"))
        raise false
      end
    end
  end

  def verify_quantity_users_per_server(sv)
    query = "(server = ?) AND
             (
                (initial_time BETWEEN ? AND ?) OR
                (
                  (initial_time + (interval '1 minutes')*duration) BETWEEN ? AND ?) OR
                  (? BETWEEN initial_time AND ((initial_time + (interval '1 minutes')*duration))) OR
                  (? BETWEEN initial_time AND ((initial_time + (interval '1 minutes')*duration)
                  )
                )
              )"
    end_time       = initial_time + duration.minutes
    webconferences = Webconference.where(query, sv, initial_time, end_time, initial_time, end_time, initial_time, end_time)
    assignment_webconferences = AssignmentWebconference.where(query, sv, initial_time, end_time, initial_time, end_time, initial_time, end_time)

    unless webconferences.empty? && assignment_webconferences.empty?
      ats      = webconferences.map(&:allocation_tags).flatten.map(&:related).flatten
      students = 0
      ats.flatten.each do |at|
        allocations = Allocation.find_by_sql <<-SQL
          SELECT COUNT(allocations.id)
          FROM allocations
          JOIN profiles ON profiles.id = allocations.profile_id
          WHERE
            cast( profiles.types & #{Profile_Type_Student} as boolean )
          AND
            allocations.allocation_tag_id = #{at}
          AND
            allocations.status = 1;
        SQL
      students += allocations.first['count'].to_i
      end
      students += assignment_webconferences.map(&:academic_allocation_user).flatten.map(&:users_count).flatten.sum unless assignment_webconferences.empty?
      students
    else
      false
    end
  end

  def cant_change_date
    errors.add(:initial_time, I18n.t("#{self.class.to_s.tableize}.error.date_new")) if (Time.now > (initial_time+duration.minutes))
    if (initial_time_was && duration_was)
      if (Time.now > (initial_time_was+duration_was.minutes))
        errors.add(:initial_time, I18n.t("#{self.class.to_s.tableize}.error.date"))
      elsif (Time.now >= initial_time_was && initial_time_changed?)
        errors.add(:initial_time, I18n.t("#{self.class.to_s.tableize}.error.started"))
      end
    end
  end

  def verify_time(allocation_tags_ids = [])
    query    = "(initial_time BETWEEN ? AND ?) OR ((initial_time + (interval '1 minutes')*duration) BETWEEN ? AND ?) OR (? BETWEEN initial_time AND ((initial_time + (interval '1 minutes')*duration))) OR (? BETWEEN initial_time AND ((initial_time + (interval '1 minutes')*duration)))"
    end_time = initial_time + duration.minutes

    objs = if respond_to?(:academic_allocation_user_id)
      AssignmentWebconference.where(academic_allocation_user_id: academic_allocation_user_id).where(query, initial_time, end_time, initial_time, end_time, initial_time, end_time)
    else
      Webconference.joins(:academic_allocations).where(academic_allocations: { allocation_tag_id: allocation_tags_ids, academic_tool_type: 'Webconference' }).where(query, initial_time, end_time, initial_time, end_time, initial_time, end_time)
    end

    if (objs - [self]).any?
      errors.add(:initial_time, I18n.t("#{self.class.to_s.tableize}.error.time_and_place"))
      raise false
    end
  end

  def bbb_online?(api = nil)
    Timeout::timeout(4) do
      api = bbb_prepare if api.nil?
      url = URI.parse(api.url)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true if url.scheme.downcase == 'https'
      response = http.get(url.request_uri)
      return (Net::HTTPSuccess === response)
    end
  rescue
    false
  end

  def bbb_prepare
    choose_server if server.blank?
    Timeout::timeout(4) do
      @config = YAML.load_file(File.join(Rails.root.to_s, 'config', 'webconference.yml'))
      bbb  = @config['servers'][@config['servers'].keys[server]]
      debug   = @config['debug']
      BigBlueButton::BigBlueButtonApi.new(bbb['url'], bbb['salt'], bbb['version'].to_s, debug)
    end
  rescue
    false
  end

  def self.bbb_prepare(server)
    Timeout::timeout(4) do
      @config = YAML.load_file(File.join(Rails.root.to_s, 'config', 'webconference.yml'))
      bbb  = @config['servers'][@config['servers'].keys[server]]
      debug   = @config['debug']
      BigBlueButton::BigBlueButtonApi.new(bbb['url'], bbb['salt'], bbb['version'].to_s, debug)
    end
  rescue
    false
  end

  def count_servers
    Timeout::timeout(4) do
      @config = YAML.load_file(File.join(Rails.root.to_s, 'config', 'webconference.yml'))
      @config['servers'].except("bbb-play").count
    end
  rescue
    false
  end

  def choose_server
    @server, best_server = nil

    (0..(count_servers-1)).to_a.shuffle.each do |sv| # Percorre os servers (aleatoriamente) que existem no .yml
      api = Bbb.bbb_prepare(sv)
      if (api && bbb_online?(api)) # Online?
        next_server = verify_quantity_users_per_server(sv) # Quantidade de usuarios por server, naquela faixa de horario
        if (!next_server) #Encerra o loop se o server estiver vazio
          @server = sv
          break
        end
        if (best_server.nil? or (next_server < best_server)) # Continua a procura pelo menos sobrecarregado
          best_server = next_server
          @server = sv
        end
      end
    end
    self.server = @server
    self.merge = true
    self.save! # BD
  end

  def exist_and_offline?(server)
    ( !server.blank? && !bbb_online?(Bbb.bbb_prepare(server)) )
  end

  def get_recordings(api = nil, meetingId)
    api = bbb_prepare if api.nil?
    raise "offline"   if api.nil?

    options = {meetingID: meetingId}
    response = api.get_recordings(options)

    response[:recordings]
  rescue => error
    return []
  end

  def get_meetings(api = nil)
    api = bbb_prepare if api.nil?
    raise "offline"   if api.nil?
    api.get_meetings[:meetings].collect{|m| m[:meetingID]}
  rescue => error
    return []
  end

  def status(at_id = nil)
    case
    when on_going? then I18n.t('webconferences.list.in_progress')
    when (Time.now < initial_time) then I18n.t('webconferences.list.scheduled')
    when !is_over? then I18n.t('webconferences.list.processing')
    else
      I18n.t('webconferences.list.finish')
    end
  end

  def recordings(recordings = [], at_id = nil)
    meeting_id = get_mettingID(at_id)
    recordings = get_recordings(meeting_id) if recordings.blank?

    return recordings
  rescue
    return []
  end

  def remove_record(recordId, at=nil)
    return true if server.blank?
    raise 'error' if !at.nil? && at.class == Array
    raise 'copy' unless self.class.to_s != 'Webconference' || origin_meeting_id.blank?
    ids = recordings([], at).collect{|a| a[:recordID]}
    raise CanCan::AccessDenied unless ids.include?(recordId)
    api = bbb_prepare
    api.delete_recordings(recordId)
  end

  # format: presentation, podcast and video
  def self.get_recording_url(recording, format)
    response = recording[:playback][:format]
    if response.kind_of?(Array)
      case format
      when 'video'
        response = response.find {|x| x[:type] == 'presentation'}
        url = response[:url][0..26]+"/download/presentation/"+recording[:recordID]+"/"+recording[:recordID]+".mp4"
        return url.to_s
      when 'slides'
      when 'chat'
      else
        response = response.find {|x| x[:type] == format}
      end
    end
    response = URI.parse(response[:url])
    response.scheme = "https"
    response.to_s
  end

  def started?
    Time.now >= initial_time
  end

  def on_going?
    Time.now.between?(initial_time, initial_time+duration.minutes)
  rescue
    (opened && !closed)
  end

  def is_over?
    # Time.now > (initial_time+duration.minutes+15.minutes)
    Time.now > (initial_time+(duration.minutes*2))
  end

  def over?
    Time.now > (initial_time+duration.minutes)
  end

  def self.get_duration(start, final)
    diff = final.to_time - start.to_time
    duration = '%dh %02dm %02ds' % [ diff / 3600, (diff / 60) % 60, diff % 60 ]
    return diff, duration
  end

  def can_destroy?
    raise raise CanCan::AccessDenied if respond_to?(:is_onwer?) && !is_onwer?
    raise 'date_range'               if respond_to?(:in_time?)  && !in_time?
    raise 'unavailable'              unless server.blank? || bbb_online?
    raise 'not_ended'                unless !started? || is_over?
    raise 'acu'                      if (respond_to?(:academic_allocation_users) && academic_allocation_users.any?) || (!respond_to?(:academic_allocation_users) && academic_allocation_user.blank?)
    raise 'integrated' if (respond_to?(:integrated) && integrated) && (api.blank? || over?)
  end

  def can_destroy_boolean?
    can_destroy?

    return true
  rescue
    return false
  end

  def can_remove_records?
    raise raise CanCan::AccessDenied if respond_to?(:is_onwer?) && !is_onwer?
    raise 'date_range'               if respond_to?(:in_time?)  && !in_time?
    raise 'unavailable'              unless server.blank? || bbb_online?
    raise 'not_ended'                unless !started? || is_over?
    raise 'copy'                     unless self.class.to_s != 'Webconference' || origin_meeting_id.blank?
    raise 'acu'                      if ((respond_to?(:academic_allocation_users) && academic_allocation_users.where(status: AcademicAllocationUser::STATUS[:evaluated]).any?) || (respond_to?(:academic_allocation_user) && academic_allocation_user.status == AcademicAllocationUser::STATUS[:evaluated]))
  end

  def meeting_info(user_id, at_id = nil, meetings = nil)
    raise nil unless on_going?
    meeting_id = get_mettingID(at_id)
    @api       = bbb_prepare
    #URI.parse(@api[:url]).path # testing url to avoid connection errors
    raise nil unless @api.test_connection
    meetings   = meetings || @api.get_meetings[:meetings].collect{|m| m[:meetingID]}
    raise nil unless !meetings.nil? && meetings.include?(meeting_id)
    response   = @api.get_meeting_info(meeting_id, Digest::MD5.hexdigest((title rescue name)+meeting_id))
    response[:participantCount]
  rescue
    0
  end

  # Retorna a quantidade de chamados em aberto
  def self.count_help
    Webconference.joins(:academic_allocations).where(academic_allocations: { support_help: Support_Help_Request}).count
  end

  def participant_count_per_server
    server = 0
    result = 0
    count = Array.new

    while (server < count_servers) do
      api = Bbb.bbb_prepare(server)
      meetings = api.get_meetings[:meetings].collect{|m| m[:meetingID]}

      if !meetings.empty?
        meetings.map {|m|
          response = api.get_meeting_info(m[:meetingID])
          result += response[:participantCount]
        }
      end
      count[server] = ['BBB ' + (server+1).to_s, result]
      server += 1
    end
    count
  rescue
    false
  end

end
