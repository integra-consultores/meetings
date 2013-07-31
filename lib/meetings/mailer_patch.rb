require Rails.root.join('lib','redmine','helpers','time_report').to_s
require Rails.root.join('app','helpers','attachments_helper.rb').to_s
require 'ri_cal'

module Meetings
  
  module MailerPatch
    include MeetingsHelper
    include AttachmentsHelper
    include ActionView::Helpers::TagHelper

    def self.included(base) # :nodoc:

      base.send(:include, InstanceMethods)

      # Same as typing in the class 
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development        
      end

    end
    
    module InstanceMethods
      # Builds a Mail::Message object used to email recipients of the meeting after it is saved.
      # Features:
      #   > can be used when meetings is added OR updated 
      #   > if the meeting is updated, includes journal (and journal_details) henece improves communication
      #   > meeting invite is added in both new meeting or updated meeting. 
      #   > if the meeting is updated, it follows sequence numbers 
      #       hence the calender app will not show up as new event rather shows this as a revision
      #   > cancellation of meeting gets reflected in calender! 
      #
      # Example:
      #   meeting_save(meeting) => Mail::Message object
      #   Mailer.meeting_save(meeting).deliver => sends an email to meeting recipients
      # This function now sends 'invite.ics' which acts as a calender invite provided the event times are well defined
      # This method must be called _after_ the create_journal method is called else it will send older journal.
      def meeting_save(meeting)
        redmine_headers 'Project' => meeting.project.identifier,
                        'Meeting-Id' => meeting.id,
                        'Meeting-Author' => meeting.author.login
        redmine_headers 'Meeting-Participants' => meeting.participants.pluck(:login).join(", ") if meeting.participants.any?
        @author = meeting.author
	@updater = User.current
        @meeting = meeting
        @meeting_url = url_for(:controller => 'meetings', :action => 'show', :id => meeting)
        recipients = meeting.recipients.map(&:mail)

	@journal_strings = get_journal_strings(meeting.journals.last,Setting.plain_text_mail?)

        cal = create_invite(meeting) 
	unless cal.nil? 
          attachments['invite.ics'] = {:mime_type => "text/calendar", :content => cal.to_s }
	end 

        mail :to => recipients,
          :subject => "[#{meeting.project.name} - #{l(:label_meeting)} ##{meeting.id}] #{meeting.subject}"
      end

      # This function creates a invite.ics files which most organizers will reflect as calender invite.
      def create_invite(meeting) 
        sequence = meeting.journals.count 
	if (meeting.status  == Meeting::STATUS_CANCELLED) 
	  status = "CANCELLED" 
	else 
	  # New meetings, Pending, and closed all are only 'CONFIRMED' as per current design. 
	  status = "CONFIRMED"
	end 

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
            event.status      = status 
	    event.sequence    = sequence
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
	cal 
      rescue RiCal::InvalidPropertyValue
	nil 
      end 

      # This function is very similar to details_for_meeting_journal_to_strings in MeetingsHelper
      # Ideally it should have been in some helper - but don't know how to call from mailer's view
      def get_journal_strings(journal, no_html=false, options={})
        journal_strings = [] 
	return journal_strings if journal.nil? 
	details = journal.details

	label = "unkonwn_field" 
        details.each do |detail|

	  if(detail.property == "attr") 
            label = l("field_#{detail.prop_key}")
            if detail.prop_key == "status"
              detail.old_value = status_display_for detail.old_value
              detail.value = status_display_for detail.value
            elsif detail.prop_key == "start_hour" 
              detail.old_value = detail.old_value.to_time.strftime("%I:%M %p") rescue ""
              detail.value = detail.value.to_time.strftime("%I:%M %p") rescue ""
            elsif detail.prop_key == "end_hour"
              detail.old_value = detail.old_value.to_time.strftime("%I:%M %p") rescue ""
              detail.value = detail.value.to_time.strftime("%I:%M %p") rescue ""
            elsif detail.prop_key == "issue_id"
              detail.value = "##{detail.value}" unless detail.value.blank?
              detail.old_value = "##{detail.old_value}" unless detail.old_value.blank?
            end
	    unless no_html 
	          label = content_tag('strong',label) 
	    end 
	    journal_strings << l(:text_journal_changed,:label => label, :old => detail.old_value, :new => detail.value).html_safe

	  elsif (detail.property == "attachment") 
	    label = l("label_attachment") 
	    unless no_html 
	          label = content_tag('strong',label) 
		  detail.value = content_tag( 'a', detail.value, 
			{ :href => url_for(:controller => 'attachments', :action => 'download', :id => detail.prop_key) } ) 
	    else 
		  detail.value = detail.value + " at "
			 + url_for(:controller => 'attachments', :action => 'download', :id => detail.prop_key).to_s
	    end 
	    journal_strings << l(:text_journal_added,:label => label, :value => detail.value).html_safe
	  end 
	  
        end # details.each
	 # Finally add notes 
	 journal_strings << journal.notes.html_safe
        journal_strings
      end
 
    end   #module InstanceMethods
  end	#Module MailerPatch
end	#Module meetings

# Guards against including the module multiple time (like in tests)
# and registering multiple callbacks
unless Mailer.included_modules.include? Meetings::MailerPatch
  Mailer.send(:include, Meetings::MailerPatch)
end
