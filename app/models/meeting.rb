class Meeting < ActiveRecord::Base
  unloadable
  include Redmine::SafeAttributes
  include MeetingsHelper
  
  # Meeting statuses
  STATUS_PENDING   = 0
  STATUS_CLOSED    = 1
  STATUS_CANCELLED = 2
  
  belongs_to :author, :class_name => "User", :foreign_key => "author_id" # nullified when author destroyed
  belongs_to :project # meetings destroyed when project destroyed
  belongs_to :issue # issue_id nullified when issue is destroyed (time_entries are updated according to users decision)
  has_many :time_entries, :dependent => :restrict
  has_many :journals, :as => :journalized, :dependent => :destroy
  has_and_belongs_to_many :participants, :class_name => "User", :uniq => true # When a user is destroyed, a callback in User destroy these relationships
  
  acts_as_attachable :after_add => :attachment_added, :after_remove => :attachment_removed
  
  attr_reader :current_journal
  delegate :notes, :notes=, :private_notes, :private_notes=, :to => :current_journal, :allow_nil => true
  
  accepts_nested_attributes_for :participants
  
  validates :author, :project, :subject, :presence => true
  validates :subject, :length => {:maximum => 80}
  
  before_save :set_default_status
  after_save :create_journal
  after_save :update_issue_ids_on_time_entries
  after_create :send_notification_email
  
  safe_attributes 'status',
    'subject',
    'description',
    'date',
    'start_hour(1i)',
    'start_hour(2i)',
    'start_hour(3i)',
    'start_hour(4i)',
    'start_hour(5i)',
    'end_hour(1i)',
    'end_hour(2i)',
    'end_hour(3i)',
    'end_hour(4i)',
    'end_hour(5i)',
    'estimated_hours',
    'notes',
    'issue_id',
    'participant_ids',
    'location',
    :if => lambda {|meeting, user| meeting.new_record? || user.allowed_to?(:edit_meetings, meeting.project) }

  safe_attributes 'notes',
    :if => lambda {|meeting, user| user.allowed_to?(:add_meeting_notes, meeting.project)}

  safe_attributes 'private_notes',
    :if => lambda {|meeting, user| meeting.new_record? && user.allowed_to?(:set_meeting_notes_private, meeting.project)}
  
  def self.visible( user = User.current)
    user.admin? ? 
    where(false) :
    self.includes(:participants).where("#{Meeting.table_name}.author_id = ? OR meetings_users.user_id = ?", user, user)
  end
  
  
  # These methods are need to use in Mailer
  def updated_on
    updated_at
  end
  
  def created_on
    created_at
  end

  # Safely sets attributes
  # Should be called from controllers instead of #attributes=
  # attr_accessible is too rough because we still want things like
  # Meeting.new(:project => foo) to work
  def safe_attributes=(attrs, user=User.current)
    return unless attrs.is_a?(Hash)

    attrs = attrs.dup
    attrs = delete_unsafe_attributes(attrs, user)
    
    return if attrs.empty?

    # mass-assignment security bypass
    assign_attributes attrs, :without_protection => true
  end
  
  # Users that participate in the meeting
  def assignable_users
    users = project.assignable_users
    users << author if author
    users.uniq.sort
  end
  
  def init_journal(user, notes = "")
    @current_journal ||= Journal.new(:journalized => self, :user => user, :notes => notes, :notify => false)
    if new_record?
      @current_journal.notify = false
    else
      @attributes_before_change = attributes.dup
    end
    @current_journal
  end
  
  # Returns the id of the last journal or nil
  def last_journal_id
    if new_record?
      nil
    else
      journals.maximum(:id)
    end
  end
  
  # Returns the total number of hours spent on this meeting
  #
  # Example:
  #   spent_hours => 0.0
  #   spent_hours => 50.2
  def total_spent_hours
    @total_spent_hours ||= TimeEntry.where(:meeting_id => id).sum(:hours).to_f
  end
  
  # Saves a meeting and a time_entry from the parameters
  def save_meeting_with_child_records(params, existing_time_entry=nil)
    Meeting.transaction do
      if params[:time_entry] && (params[:time_entry][:hours].present? || params[:time_entry][:comments].present?) && User.current.allowed_to?(:log_time, project)
        @time_entry = existing_time_entry || TimeEntry.new
        @time_entry.project = project
        @time_entry.meeting = self
        @time_entry.user = User.current
        @time_entry.spent_on = User.current.today
        @time_entry.attributes = params[:time_entry]
        self.time_entries << @time_entry
      end
      
      raise ActiveRecord::Rollback unless save
    end
    true
  end
  
  # Returns a scope for journals that have an id greater than journal_id
  def journals_after(journal_id)
    scope = journals.reorder("#{Journal.table_name}.id ASC")
    if journal_id.present?
      scope = scope.where("#{Journal.table_name}.id > ?", journal_id.to_i)
    end
    scope
  end
  
  def to_s
    "#{l(:label_meeting)} ##{id}: #{subject}"
  end
  
  def recipients
    [author].concat(participants).delete_if(&:nil?)
  end
  
  def display_status
    status_display_for self
  end
  
  private
  
  # Saves the changes in a Journal
  # Called after_save
  def create_journal
    if @current_journal
      # attributes changes
      if @attributes_before_change
        (Meeting.column_names - %w(id created_at updated_at)).each {|c|
          before = @attributes_before_change[c]
          after = send(c)
          next if before == after || (before.blank? && after.blank?)
          @current_journal.details << JournalDetail.new(:property => 'attr',
                                                        :prop_key => c,
                                                        :old_value => before,
                                                        :value => after)
        }
      end
      @current_journal.save
      # reset current journal
      init_journal @current_journal.user, @current_journal.notes
    end
  end
  
  def set_default_status
    self.status ||= STATUS_PENDING
  end
  
  # Callback on file attachment
  def attachment_added(obj)
    if @current_journal && !obj.new_record?
      @current_journal.details << JournalDetail.new(:property => 'attachment', :prop_key => obj.id, :value => obj.filename)
    end
  end

  # Callback on attachment deletion
  def attachment_removed(obj)
    if @current_journal && !obj.new_record?
      @current_journal.details << JournalDetail.new(:property => 'attachment', :prop_key => obj.id, :old_value => obj.filename)
      @current_journal.save
    end
  end
  
  def update_issue_ids_on_time_entries
    time_entries.update_all(:issue_id => issue_id)
  end
  
  def send_notification_email
    logger.info "Sending email about new meeting"
    Mailer.meeting_add(self).deliver# if Setting.notified_events.include?('issue_added')
  end
end
