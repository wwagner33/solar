class Message < ActiveRecord::Base

  belongs_to :allocation_tag
  has_one :group, through: :allocation_tag

  has_many :files, class_name: "MessageFile"
  has_many :users, through: :user_messages, uniq: true
  has_many :user_messages
  has_many :user_message_labels, through: :user_messages, uniq: true
  has_many :message_labels, through: :user_message_labels, uniq: true

  before_save proc { |record| record.subject = I18n.t(:no_subject, scope: :messages) if record.subject == "" }
  before_save :set_sender_and_recipients, if: "sender"

  scope :by_user, ->(user_id) { joins(:user_messages).where(user_messages: { user_id: user_id }) }

  accepts_nested_attributes_for :user_messages, allow_destroy: true
  accepts_nested_attributes_for :files, allow_destroy: true

  self.per_page = Rails.application.config.items_per_page

  attr_accessor :contacts, :sender

  def sent_by
    user_messages.where("cast(user_messages.status & #{Message_Filter_Sender} as boolean)").first.user
  end

  def recipients
    users.where("NOT cast(user_messages.status & #{Message_Filter_Sender} as boolean)")
  end

  def labels(user_id = nil, system_label = true)
    l = []
    l << message_labels.where(user_id: user_id).pluck(:name) if user_id # label criada pelo usuário (funcionalidade futura)
    l << group.as_label if system_label && allocation_tag_id # label pela turma (default do sistema)
    l.flatten.compact.uniq
  end

  def self.get_query(user_id, box='inbox', allocation_tags_ids=[], options={ ignore_trash: true, only_unread: false })
    query = []
    case box
    when 'inbox'
      query << "NOT cast(user_messages.status & #{Message_Filter_Sender + Message_Filter_Trash} as boolean)"
      query << "NOT cast(user_messages.status & #{Message_Filter_Read} as boolean)" if options[:only_unread]
    when 'outbox'
      query << "cast(user_messages.status & #{Message_Filter_Sender} as boolean)"
      query << "NOT cast(user_messages.status & #{Message_Filter_Trash} as boolean)" if options[:ignore_trash]
    when 'trashbox'
      query << "cast(user_messages.status & #{Message_Filter_Trash} as boolean)"
    end

    ats = [allocation_tags_ids].flatten.compact

    query << "messages.allocation_tag_id IN (#{ats.join(',')})" unless ats.blank?
    query << "user_messages.user_id = #{user_id}"
    query.join(' AND ')
  end

  def self.by_box(user_id, box='inbox', allocation_tags_ids=[], options={ ignore_trash: true, only_unread: false })
    query = Message.get_query(user_id, box, allocation_tags_ids, options)

    Message.find_by_sql <<-SQL
      SELECT DISTINCT messages.id, messages.*, 
        sent_by.name AS sent_by_name,
        COUNT(message_files.id) AS count_files,
        COUNT(readed_messages.id) AS was_read
      FROM messages
      JOIN user_messages      ON messages.id = user_messages.message_id
      LEFT JOIN message_files ON messages.id = message_files.message_id
      LEFT JOIN (
        SELECT um.id
          FROM user_messages um
          WHERE (
            cast(um.status & #{Message_Filter_Read} as boolean) 
            OR cast(um.status & #{Message_Filter_Sender} as boolean)
          )
      ) readed_messages ON readed_messages.id = user_messages.id
      LEFT JOIN (
        SELECT users.name AS name, um.message_id AS id
          FROM users
          JOIN user_messages um ON um.user_id = users.id
          WHERE cast(um.status & #{Message_Filter_Sender} as boolean)
      ) sent_by ON sent_by.id = messages.id
      WHERE #{query}
      GROUP BY user_messages.status, user_messages.user_id, sent_by.name, messages.id
      ORDER BY created_at DESC;
    SQL
  end

  def self.sent_by_user(user_id, allocation_tags_ids = [])
    query = Message.get_query(user_id, 'outbox', allocation_tags_ids, { ignore_trash: false })
    sent  = Message.find_by_sql <<-SQL
      SELECT COUNT(*) FROM (
        SELECT DISTINCT messages.id
        FROM messages
        JOIN user_messages ON user_messages.message_id = messages.id
        WHERE #{query}
      ) AS msgs;
    SQL
    sent.first[:count]
  end

  def self.unreads(user_id, allocation_tags_ids=[])
    sql = (allocation_tags_ids.blank? ? '' : " AND messages.allocation_tag_id IN (#{[allocation_tags_ids].flatten.join(',')})")
    unreads = Message.find_by_sql <<-SQL
      SELECT COUNT(*) FROM (
        SELECT DISTINCT messages.id
        FROM messages
        JOIN user_messages ON user_messages.message_id = messages.id
        WHERE 
          user_messages.user_id = #{user_id}
          AND NOT cast(user_messages.status & #{Message_Filter_Read + Message_Filter_Sender + Message_Filter_Trash} as boolean)
          #{sql}
      ) AS msgs;
    SQL

    unreads.first[:count]
  end

  def user_has_permission?(user_id)
    user_messages.where(user_id: user_id).count > 0
  end

  private

    def set_sender_and_recipients
      users = [{user: sender, status: Message_Filter_Sender}]
      users << contacts.split(",").map {|u| {user_id: u, status: Message_Filter_Receiver}} unless contacts.blank?

      self.user_messages.build users
    end

end
