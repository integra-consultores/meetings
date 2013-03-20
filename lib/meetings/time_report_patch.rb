require Rails.root.join('lib','redmine','helpers','time_report').to_s

module Meetings
  
  module TimeReportPatch
    
    def self.included(base) # :nodoc:

      base.send(:include, InstanceMethods)

      # Same as typing in the class 
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        
        alias_method_chain :load_available_criteria, :meeting
      end

    end
    
    module InstanceMethods
      def load_available_criteria_with_meeting
        criterias = load_available_criteria_without_meeting
        criterias['meeting'] = {:sql => "#{TimeEntry.table_name}.meeting_id",
                                :klass => Meeting,
                                :label => :label_meeting}
        criterias
      end
    end
    
  end
end

# Guards against including the module multiple time (like in tests)
# and registering multiple callbacks
unless Redmine::Helpers::TimeReport.included_modules.include? Meetings::TimeReportPatch
  Redmine::Helpers::TimeReport.send(:include, Meetings::TimeReportPatch)
end