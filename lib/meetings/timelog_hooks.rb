module Meetings
  class TimelogHooks < Redmine::Hook::ViewListener
    include MeetingsHelper
    
    def view_timelog_index_list_after_entry(context={})
      entry = context[:entry]
      entry.meeting.nil? ? "" :
        %Q{
          <script type="text/javascript">
            elem = $('tr#time-entry-#{entry.id} td.subject')
            str = elem.html();
            str = (!str || /^\\s*$/.test(str)) ? str : str + ' / ' ;
            elem.html(str + '#{link_to_meeting(entry.meeting, :truncate => 50)}')
          </script>
        }.html_safe
    end  
    
    # Add meeting_id field and javascript for autocomplete meeting_id
    # It should fix the menu_item depending on the url but it doesn't yet. 
    render_on :view_timelog_edit_form_bottom, :partial => "time_log/timelog_edit_form_bottom"
    
    def view_time_entries_bulk_edit_details_bottom(context={})
      %Q{
        <p>
          <label>#{l(:field_meeting)}</label>
          #{text_field :time_entry, :meeting_id, :size => 6 }
        </p>
      }      
    end
  end
end