require 'user'

module Meetings
  
  module UserPatch
    
    def self.included(base) # :nodoc:

      base.send(:include, InstanceMethods)

      # Same as typing in the class 
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development

       has_many :authored_meetings, :class_name => "Meeting", :foreign_key => "author_id"
       has_and_belongs_to_many :meetings
       
       before_destroy :remove_links_for_meetings_before_destroy
      end

    end
    
    module InstanceMethods
      def remove_links_for_meetings_before_destroy        
        return if self.id.nil?

        substitute = User.anonymous
        Meeting.update_all ["author_id = ?", substitute.id], ["author_id = ?", id]
        meetings = []
      end
    end
    
  end
end

# Guards against including the module multiple time (like in tests)
# and registering multiple callbacks
unless User.included_modules.include? Meetings::UserPatch
  User.send(:include, Meetings::UserPatch)
end