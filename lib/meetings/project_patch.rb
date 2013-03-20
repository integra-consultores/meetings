require 'project'

module Meetings
  
  module ProjectPatch
    
    def self.included(base) # :nodoc:

      # Same as typing in the class 
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        
        has_many :meetings, :dependent => :destroy 
      end

    end
    
  end
end

# Guards against including the module multiple time (like in tests)
# and registering multiple callbacks
unless Project.included_modules.include? Meetings::ProjectPatch
  Project.send(:include, Meetings::ProjectPatch)
end