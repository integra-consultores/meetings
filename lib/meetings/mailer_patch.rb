require Rails.root.join('lib','redmine','helpers','time_report').to_s
require 'ri_cal'

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
      # This function now sends 'invite.ics' which acts as a calender invite provided the event times are well defined
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

        cal = RiCal.Calendar do |cal|
          cal.prodid           = "REDMINE-MEETINGS-PLUGIN"
          cal.method_property  = ":REQUEST"
          cal.event do |event|
            event.dtstamp     = DateTime.now.utc
            event.summary     = meeting.subject
            event.description = meeting.description
	    event.dtstart     = "TZID=#{meeting.local_time_zone}:#{meeting.event_start_hour}"
	    event.dtend       = "TZID=#{meeting.local_time_zone}:#{meeting.event_end_hour}"
            event.location    = meeting.location
            meeting.recipients.collect.sort.each do |user|
              event.add_attendee  user.mail
            end
            event.organizer   = meeting.author.mail
            event.uid         = "AEEADBAF-0000-0000-#{"%012d" % meeting.id}"
	    # New meeting is always 'CONFIRMED' as per current design. Updates can have TENTATIVE/CANCEL
            event.status      = "CONFIRMED"
            event.class_property = ":PUBLIC"
            event.priority    = 5
            event.transp      = "OPAQUE"
            event.alarm do
              description "REMINDER"
              action "DISPLAY"
              trigger_property ";RELATED=START:-PT5M"
            end
          end
        end

        attachments['invite.ics'] = {:mime_type => "text/calendar", :content => cal.to_s }
        mail :to => recipients,
          :subject => "[#{meeting.project.name} - #{l(:label_meeting)} ##{meeting.id}] #{meeting.subject}"

      rescue RiCal::InvalidPropertyValue
	# Incase we don't have proper values to generate 'invite.ics' - just send normal mail
        mail :to => recipients,
          :subject => "[#{meeting.project.name} - #{l(:label_meeting)} ##{meeting.id}] #{meeting.subject}"
      end

      def meeting_update(meeting)
        redmine_headers 'Project' => meeting.project.identifier,
                        'Meeting-Id' => meeting.id,
                        'Meeting-Author' => meeting.author.login
        redmine_headers 'Meeting-Participants' => meeting.participants.pluck(:login).join(", ") if meeting.participants.any?
        #message_id meeting
        @author = meeting.author
	@updater = User.current
        @meeting = meeting
        @meeting_url = url_for(:controller => 'meetings', :action => 'show', :id => meeting)
        recipients = meeting.recipients.map(&:mail)

        cal = RiCal.Calendar do |cal|
          cal.prodid           = "REDMINE-MEETINGS-PLUGIN"
          cal.method_property  = ":REQUEST"
          cal.event do |event|
            event.dtstamp     = DateTime.now.utc
            event.summary     = meeting.subject
            event.description = meeting.description
	    event.dtstart     = "TZID=#{meeting.local_time_zone}:#{meeting.event_start_hour}"
	    event.dtend       = "TZID=#{meeting.local_time_zone}:#{meeting.event_end_hour}"
            event.location    = meeting.location
            meeting.recipients.collect.sort.each do |user|
              event.add_attendee  user.mail
            end
            event.organizer   = meeting.author.mail
            event.uid         = "AEEADBAF-0000-0000-#{"%012d" % meeting.id}"
	    # New meeting is always 'CONFIRMED' as per current design. Updates can have TENTATIVE/CANCEL
            event.status      = "CONFIRMED"
            event.class_property = ":PUBLIC"
            event.priority    = 5
            event.transp      = "OPAQUE"
            event.alarm do
              description "REMINDER"
              action "DISPLAY"
              trigger_property ";RELATED=START:-PT5M"
            end
          end
        end

        attachments['invite.ics'] = {:mime_type => "text/calendar", :content => cal.to_s }
        mail :to => recipients,
          :subject => "[#{meeting.project.name} - #{l(:label_meeting)} ##{meeting.id}] #{meeting.subject}"

      rescue RiCal::InvalidPropertyValue
	# Incase we don't have proper values to generate 'invite.ics' - just send normal mail
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
