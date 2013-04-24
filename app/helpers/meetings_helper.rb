module MeetingsHelper  
  def status_display_for meeting_or_status
    status = meeting_or_status.status rescue meeting_or_status.to_i
    case status
    when 0 then l(:status_pending)
    when 1 then l(:status_closed)
    when 2 then l(:status_cancelled)
    else ""
    end
  end
  
  def options_for_meeting_status(meeting = nil)
    options = []
    options.push [l(:status_pending), Meeting::STATUS_PENDING] if !meeting || meeting.status == Meeting::STATUS_PENDING || User.current.admin?
    options.push [l(:status_closed), Meeting::STATUS_CLOSED] if !meeting || [Meeting::STATUS_PENDING, Meeting::STATUS_CLOSED].include?( meeting.try(:status)) || User.current.admin?
    options.push [l(:status_cancelled), Meeting::STATUS_CANCELLED] if !meeting || [Meeting::STATUS_PENDING, Meeting::STATUS_CANCELLED].include?( meeting.try(:status)) || User.current.admin?
    options
  end
  
  def details_for_meeting_journal_to_strings(details, no_html=false, options={})
    options[:only_path] = (options[:only_path] == false ? false : true)
    strings = []
    details.each do |detail|
      if detail.prop_key == "status"
        detail.old_value = status_display_for detail.old_value
        detail.value = status_display_for detail.value
      elsif ["start_hour", "end_hour"].include? detail.prop_key
        detail.old_value = detail.old_value.to_time.strftime("%I:%M %p") rescue ""
        detail.value = detail.value.to_time.strftime("%I:%M %p") rescue ""
      elsif detail.prop_key == "issue_id"
        detail.value = "##{detail.value}" unless detail.value.blank?
        detail.old_value = "##{detail.old_value}" unless detail.old_value.blank?
      end
      strings << show_detail(detail, no_html, options)
    end
    strings
  end
  
  # Displays a link to +meeting+ with its subject.
  # Examples:
  #
  #   link_to_meeting(meeting)                        # => Meeting #6: This is the subject
  #   link_to_meeting(meeting, :truncate => 6)        # => Meeting #6: This i...
  #   link_to_meeting(meeting, :subject => false)     # => Meeting #6
  #   link_to_meeting(meeting, :project => true)      # => Foo - Meeting #6
  #
  def link_to_meeting(meeting, options={})
    title = nil
    subject = nil
    text = "#{l(:label_meeting_singular)} ##{meeting.id}"
    if options[:subject] == false
      title = truncate(meeting.subject, :length => 60)
    else
      subject = meeting.subject
      if options[:truncate]
        subject = truncate(subject, :length => options[:truncate])
      end
    end
    s = link_to text, meeting_path(meeting), :title => title
    s << h(": #{subject}") if subject
    s = h("#{meeting.project} - ") + s if options[:project]
    s
  end
end
