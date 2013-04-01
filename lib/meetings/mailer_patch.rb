require Rails.root.join('lib','redmine','helpers','time_report').to_s

module Meetings
  
  module MailerPatch
    
    def self.included(base) # :nodoc:

      base.send(:include, InstanceMethods)

      # Same as typing in the class 
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development        
      end

    end
    
    module InstanceMethods
      # Builds a Mail::Message object used to email recipients of the added meeting.
      #
      # Example:
      #   meeting_add(meeting) => Mail::Message object
      #   Mailer.meeting_add(meeting).deliver => sends an email to meeting recipients
      def meeting_add(meeting)
        redmine_headers 'Project' => meeting.project.identifier,
                        'Meeting-Id' => meeting.id,
                        'Meeting-Author' => meeting.author.login
        redmine_headers 'Meeting-Participants' => meeting.participants.pluck(:login).join(", ") if meeting.participants.any?
        #message_id meeting
        @author = meeting.author
        @meeting = meeting
        @meeting_url = url_for(:controller => 'meetings', :action => 'show', :id => meeting)
        recipients = meeting.recipients.map(&:mail)
        mail :to => recipients,
          :subject => "[#{meeting.project.name} - #{l(:label_meeting)} ##{meeting.id}] #{meeting.subject}"
      end
    end    
  end
end

# Guards against including the module multiple time (like in tests)
# and registering multiple callbacks
unless Mailer.included_modules.include? Meetings::MailerPatch
  Mailer.send(:include, Meetings::MailerPatch)
end