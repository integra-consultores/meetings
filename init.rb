ActionDispatch::Callbacks.to_prepare do
  # require to refresh in development
  # require to load only when server starts
  require 'meetings/project_patch'
  require 'meetings/time_entry_patch'
  require 'meetings/timelog_hooks'
  require 'meetings/time_report_patch'
  require 'meetings/issue_patch'
  require 'meetings/mailer_patch'
  require 'meetings/user_patch'
end

Redmine::Plugin.register :meetings do
  name 'Meetings plugin'
  author 'Bishma Stornelli'
  description 'Plugin for managing meetings to allow users report time on meetings'
  version '0.0.2'
  
  menu :application_menu , 
        :meetings, {:controller => 'meetings', :action => 'index'}, 
        :caption => :label_meeting_plural,
        :if => Proc.new{ User.current.allowed_to?(:view_meetings, nil, :global => true) }
  menu :project_menu , 
        :meetings, {:controller => 'meetings', :action => 'index'}, 
        :caption => :label_meeting_plural, :after => :new_issue, :param => :project_id,
        :if => Proc.new{ |project| User.current.allowed_to?(:view_meetings, project ) }
  
  project_module :meetings do
    
    permission :view_meetings, {:meetings => [:index, :show]}
    permission :add_meetings, {:meetings => [:new, :create]}
    permission :edit_meetings, {:meetings => [:update, :edit]}
    permission :delete_meetings, {:meetings => [:destroy]}
    permission :add_meeting_notes, {:meetings => [:edit, :update], :journals => [:new], :attachments => [:upload]}
    #permission :edit_meeting_notes, {:journals => [:edit]}
    #permission :edit_own_meeting_notes, {:journals => [:edit]}
    #permission :view_private_meeting_notes
    #permission :set_meeting_notes_private 
  end
end