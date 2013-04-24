module MeetingQueriesHelper
  # Retrieve query from session or build a new query
  def retrieve_query
    if !params[:meeting_query_id].blank?
      cond = "project_id IS NULL"
      cond << " OR project_id = #{@project.id}" if @project
      @query = MeetingQuery.find(params[:meeting_query_id], :conditions => cond)
      raise ::Unauthorized unless @query.visible?
      @query.project = @project
      session[:query] = {:id => @query.id, :project_id => @query.project_id}
      sort_clear
    elsif api_request? || params[:set_filter] || session[:meeting_query].nil? || session[:meeting_query][:project_id] != (@project ? @project.id : nil)
      # Give it a name, required to be valid
      @query = MeetingQuery.new(:name => "_")
      @query.project = @project
      build_query_from_params
      session[:meeting_query] = {:project_id => @query.project_id, :filters => @query.filters, :group_by => @query.group_by, :column_names => @query.column_names}
    else
      # retrieve from session
      @query = MeetingQuery.find_by_id(session[:meeting_query][:id]) if session[:meeting_query][:id]
      @query ||= MeetingQuery.new(:name => "_", :filters => session[:meeting_query][:filters], :group_by => session[:meeting_query][:group_by], :column_names => session[:meeting_query][:column_names])
      @query.project = @project
    end
  end
  
  def build_query_from_params
    if params[:fields] || params[:f]
      @query.filters = {}
      @query.add_filters(params[:fields] || params[:f], params[:operators] || params[:op], params[:values] || params[:v])
    else
      @query.available_filters.keys.each do |field|
        @query.add_short_filter(field, params[field]) if params[field]
      end
    end
    @query.group_by = params[:group_by] || (params[:meeting_query] && params[:meeting_query][:group_by])
    @query.column_names = params[:c] || (params[:meeting_query] && params[:meeting_query][:column_names])
  end
  
  def filters_options_for_select(query)
    options_for_select(filters_options(query))
  end

  def filters_options(query)
    options = [[]]
    sorted_options = query.available_filters.sort do |a, b|
      ord = 0
      if !(a[1][:order] == 20 && b[1][:order] == 20) 
        ord = a[1][:order] <=> b[1][:order]
      else
        cn = (CustomField::CUSTOM_FIELDS_NAMES.index(a[1][:field].class.name) <=>
                CustomField::CUSTOM_FIELDS_NAMES.index(b[1][:field].class.name))
        if cn != 0
          ord = cn
        else
          f = (a[1][:field] <=> b[1][:field])
          if f != 0
            ord = f
          else
            # assigned_to or author 
            ord = (a[0] <=> b[0])
          end
        end
      end
      ord
    end
    options += sorted_options.map do |field, field_options|
      [field_options[:name], field]
    end
  end
  
  def available_block_columns_tags(query)
    tags = ''.html_safe
    query.available_block_columns.each do |column|
      tags << content_tag('label', check_box_tag('c[]', column.name.to_s, query.has_column?(column)) + " #{column.caption}", :class => 'inline')
    end
    tags
  end

  def column_header(column)
    column.sortable ? sort_header_tag(column.name.to_s, :caption => column.caption,
                                                        :default_order => column.default_order) :
                      content_tag('th', h(column.caption))
  end

  def column_content(column, meeting)
    value = column.value(meeting)
    if value.is_a?(Array)
      value.collect {|v| column_value(column, meeting, v)}.compact.join(', ').html_safe
    else
      column_value(column, meeting, value)
    end
  end
  
  def column_value(column, meeting, value)
    case value.class.name
    when 'String'
      if column.name == :subject
        link_to(h(value), :controller => 'meetings', :action => 'show', :id => meeting)
      elsif column.name == :description
        meeting.description? ? content_tag('div', textilizable(meeting, :description), :class => "wiki") : ''
      else
        h(value)
      end
    when 'Time'
      format_time(value)
    when 'Date'
      format_date(value)
    when 'Fixnum', 'Float'
      if column.name == :done_ratio
        progress_bar(value, :width => '80px')
      elsif  column.name == :spent_hours
        sprintf "%.2f", value
      elsif column.name == :status
        h(status_display_for(value))
      else
        h(value.to_s)
      end
    when 'User'
      link_to_user value
    when 'Project'
      link_to_project value
    when 'TrueClass'
      l(:general_text_Yes)
    when 'FalseClass'
      l(:general_text_No)
    when 'Issue'
      link_to_issue(value, :subject => false)
    else
      h(value)
    end
  end
end