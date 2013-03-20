require 'issue'

module Meetings
  
  module IssuePatch
    
    def self.included(base) # :nodoc:

      # Same as typing in the class 
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        
        has_many :meetings, :dependent => :nullify 
      end

    end
    
  end
end

# Guards against including the module multiple time (like in tests)
# and registering multiple callbacks
unless Issue.included_modules.include? Meetings::IssuePatch
  Issue.send(:include, Meetings::IssuePatch)
end