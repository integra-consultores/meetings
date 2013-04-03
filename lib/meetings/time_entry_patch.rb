require 'time_entry'

module Meetings
  
  module TimeEntryPatch
    
    def self.included(base) # :nodoc:

      base.send(:include, InstanceMethods)

      # Same as typing in the class 
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        
        belongs_to :meeting
        
        scope :on_meeting, lambda {|meeting| {
          :include => :meeting,
          :conditions => "#{Meeting.table_name}.id = #{meeting.id}"
        }}
        
        validate :validate_meeting_id
        
        safe_attributes 'meeting_id'
        
        after_save :set_issue_id_according_to_meeting
      end

    end
    
    module InstanceMethods
      def validate_meeting_id
        errors.add :meeting_id, :invalid if (meeting_id && !meeting) || (meeting && project!=meeting.project)
      end
      
      def set_issue_id_according_to_meeting
        logger.debug "Setting issue id according to meeting"
        if meeting_id
          logger.debug "Updating issue id to #{meeting.issue_id}"
          update_column "issue_id", meeting.issue_id
        end
        true
      end
    end
    
  end
end

# Guards against including the module multiple time (like in tests)
# and registering multiple callbacks
unless TimeEntry.included_modules.include? Meetings::TimeEntryPatch
  TimeEntry.send(:include, Meetings::TimeEntryPatch)
end