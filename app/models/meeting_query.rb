class MeetingQuery < Query
  include MeetingsHelper
  
  attr_reader :available_columns, :operators_by_filter_type
  def initialize(attributes=nil, *args)
    super attributes, *args
    self.filters.delete 'status_id' if self.filters.respond_to? :delete
    self.filters['status'] = {:operator => "=", :values => ["0"]}
    @is_for_all = project.nil?
    
    @available_columns = [
      QueryColumn.new(:project, :groupable => true),
      QueryColumn.new(:status, :groupable => true),
      QueryColumn.new(:subject),
      QueryColumn.new(:author, :groupable => true),
      QueryColumn.new(:participants, :groupable => true),
      QueryColumn.new(:updated_at, :default_order => 'desc'),
      QueryColumn.new(:date),
      QueryColumn.new(:estimated_hours),
      QueryColumn.new(:created_at, :default_order => 'desc'),
      QueryColumn.new(:issue, :caption => :label_related_issues),
    ]
    @operators_by_filter_type = { :list => [ "=", "!" ],
                                 :list_status => [ "=", "!", "*" ],
                                 :list_optional => [ "=", "!", "!*", "*" ],
                                 :list_subprojects => [ "*", "!*", "=" ],
                                 :date => [ "=", ">=", "<=", "><", "<t+", ">t+", "><t+", "t+", "t", "w", ">t-", "<t-", "><t-", "t-", "!*", "*" ],
                                 :date_past => [ "=", ">=", "<=", "><", ">t-", "<t-", "><t-", "t-", "t", "w", "!*", "*" ],
                                 :string => [ "=", "~", "!", "!~", "!*", "*" ],
                                 :text => [  "~", "!~", "!*", "*" ],
                                 :integer => [ "=", ">=", "<=", "><", "!*", "*" ],
                                 :float => [ "=", ">=", "<=", "><", "!*", "*" ],
                                 :relation => ["=", "=p", "=!p", "!p", "!*", "*"]}
  end
  
  def available_filters
    return @available_filters if @available_filters
    @available_filters = {
      "status" => {
        :type => :list_status, :order => 0,
        :values => options_for_meeting_status.map{|k,v| [k.to_s, v.to_s]}
       },
      "subject" => { :type => :text, :order => 8 },
      "date" => { :type => :date, :order => 9 },
      "estimated_hours" => { :type => :float, :order => 13 },
      "created_at" => { :type => :date_past, :order => 11 },
      "updated_at" => { :type => :date_past, :order => 12 }
    }
    principals = []
    if project
      principals += project.principals.sort
      unless project.leaf?
        subprojects = project.descendants.visible.all
        if subprojects.any?
          @available_filters["subproject_id"] = {
            :type => :list_subprojects, :order => 13,
            :values => subprojects.collect{|s| [s.name, s.id.to_s] }
          }
          principals += Principal.member_of(subprojects)
        end
      end
    else
      if all_projects.any?
        # members of visible projects
        principals += Principal.member_of(all_projects)
        # project filter
        project_values = []
        if User.current.logged? && User.current.memberships.any?
          project_values << ["<< #{l(:label_my_projects).downcase} >>", "mine"]
        end
        project_values += all_projects_values
        @available_filters["project_id"] = {
          :type => :list, :order => 1, :values => project_values
        } unless project_values.empty?
      end
    end
    principals.uniq!
    principals.sort!
    users = principals.select {|p| p.is_a?(User)}

    author_values = []
    author_values << ["<< #{l(:label_me)} >>", "me"] if User.current.logged?
    author_values += users.collect{|s| [s.name, s.id.to_s] }
    @available_filters["author_id"] = {
      :type => :list, :order => 5, :values => author_values
    } unless author_values.empty?

    @available_filters.each do |field, options|
      options[:name] ||= l(options[:label] || "field_#{field}".gsub(/_id$/, ''))
    end
    @available_filters
  end
  
  # Returns the meeting count
  def meeting_count
    Meeting.visible.count(:include => [:project], :conditions => statement)
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end
  
  # Returns the meetings
  # Valid options are :order, :offset, :limit, :include, :conditions
  def meetings(options={})
    order_option = [group_by_sort_order, options[:order]].reject {|s| s.blank?}.join(',')
    order_option = nil if order_option.blank?

    meetings = Meeting.visible.scoped(:conditions => options[:conditions]).find :all, :include => ([:project] + (options[:include] || [])).uniq,
                     :conditions => statement,
                     :order => order_option,
                     :joins => joins_for_order_statement(order_option),
                     :limit  => options[:limit],
                     :offset => options[:offset]

    #if has_column?(:spent_hours)
    #  Issue.load_visible_spent_hours(issues)
    #end
    #if has_column?(:relations)
    #  Issue.load_visible_relations(issues)
    #end
    meetings
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end
  
  # Additional joins required for the given sort options
  def joins_for_order_statement(order_options)
    joins = []

    if order_options
      if order_options.include?('authors')
        joins << "LEFT OUTER JOIN #{User.table_name} authors ON authors.id = #{Meeting.table_name}.author_id"
      end
    end

    joins.any? ? joins.join(' ') : nil
  end
  
  # Returns the meeting count by group or nil if query is not grouped
  def meeting_count_by_group
    r = nil
    if grouped?
      begin
        # Rails3 will raise an (unexpected) RecordNotFound if there's only a nil group value
        r = Meeting.visible.count(:group => group_by_statement, :include => [:project], :conditions => statement)
      rescue ActiveRecord::RecordNotFound
        r = {nil => meeting_count}
      end
      c = group_by_column
    end
    r
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end
  
  def statement
    # filters clauses
    filters_clauses = []
    filters.each_key do |field|
      next if field == "subproject_id"
      v = values_for(field).clone
      next unless v and !v.empty?
      operator = operator_for(field)
      # "me" value subsitution
      if %w(author_id).include?(field)
        if v.delete("me")
          if User.current.logged?
            v.push(User.current.id.to_s)
          else
            v.push("0")
          end
        end
      end

      if field == 'project_id'
        if v.delete('mine')
          v += User.current.memberships.map(&:project_id).map(&:to_s)
        end
      end

      if field =~ /cf_(\d+)$/
        # custom field
        filters_clauses << sql_for_custom_field(field, operator, v, $1)
      elsif respond_to?("sql_for_#{field}_field")
        # specific statement
        filters_clauses << send("sql_for_#{field}_field", field, operator, v)
      else
        # regular field
        filters_clauses << '(' + sql_for_field(field, operator, v, Meeting.table_name, field) + ')'
      end
    end if filters and valid?

    filters_clauses << project_statement
    filters_clauses.reject!(&:blank?)

    filters_clauses.any? ? filters_clauses.join(' AND ') : nil
  end

end