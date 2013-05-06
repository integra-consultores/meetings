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

	zone_name = ActiveSupport::TimeZone::MAPPING.keys.find do |name|
	  ActiveSupport::TimeZone[name].utc_offset == Time.now.utc_offset
	end
		
	time_zone_str  = ActiveSupport::TimeZone.find_tzinfo(zone_name).identifier
	date_str       = "#{meeting.date.strftime("%Y%m%d")}"
	start_time_str = "#{meeting.start_hour.strftime("%H%M%S")}"
	end_time_str   = "#{meeting.end_hour.strftime("%H%M%S")}"
	dt_start       = "TZID=#{time_zone_str}:#{date_str}T#{start_time_str}" 
	dt_end         = "TZID=#{time_zone_str}:#{date_str}T#{end_time_str}" 
	
        cal = RiCal.Calendar do |cal|
          cal.prodid           = "REDMINE-MEETINGS-PLUGIN"
          cal.method_property  = ":REQUEST"
          cal.event do |event|
            event.dtstamp     = DateTime.now.utc
            event.summary     = meeting.subject
            event.description = meeting.description
	    event.dtstart     = dt_start
	    event.dtend       = dt_end
            event.location    = meeting.location
            meeting.recipients.collect.sort.each do |user|
              event.add_attendee  user.mail
            end
            event.organizer   = meeting.author.mail
            event.uid         = "B10AA0B0-0000-0000-#{"%012d" % meeting.id}"
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
      end
    end    
  end
end

# Guards against including the module multiple time (like in tests)
# and registering multiple callbacks
unless Mailer.included_modules.include? Meetings::MailerPatch
  Mailer.send(:include, Meetings::MailerPatch)
end
