class MeetingsController < ApplicationController
  unloadable

  before_filter :remove_date_in_hours_fields, :only => [:create, :update]
  before_filter :find_meeting, :only => [:show, :edit, :update, :destroy]
  before_filter :find_project
  before_filter :authorize, :except => [:index, :meetings]
  before_filter :find_optional_project, :only => [:index]
  
  helper :journals
  helper :projects
  include ProjectsHelper
  helper :attachments
  include AttachmentsHelper
  helper :timelog
  helper :issues
  include IssuesHelper
  helper :meetings
  include MeetingsHelper
  helper :meeting_queries
  include MeetingQueriesHelper
  helper :sort
  include SortHelper
  
  def new
    @meeting = Meeting.new :project_id => @project.id
  end

  def create
    @meeting = Meeting.new params[:meeting]
    @meeting.project = @project
    @meeting.author = User.current
    if @meeting.save
      respond_to do |format|
        format.html {
          flash[:notice] = l(:notice_meeting_successful_create)
          redirect_to(params[:continue] ?  { :action => 'new', :project_id => @meeting.project} :
                      { :action => 'show', :id => @meeting })
        }
      end
      return
    else
      respond_to do |format|
        format.html{ render :action => 'new' }
      end
    end
  end

  def show
    @journals = @meeting.journals.includes(:user, :details).reorder("#{Journal.table_name}.id ASC").all
    @journals.each_with_index {|j,i| j.indice = i+1}
    @journals.reject!(&:private_notes?) unless User.current.allowed_to?(:view_private_notes, @meeting.project)
    @journals.reverse! if User.current.wants_comments_in_reverse_order?
    
    @time_entry = TimeEntry.new(:meeting => @meeting, :project => @meeting.project)
    
    @edit_allowed = User.current.allowed_to?(:edit_meetings, @project)
  end

  def edit
    return unless update_meeting_from_params

    respond_to do |format|
      format.html { }
    end
  end

  def update
    return unless update_meeting_from_params
    @meeting.save_attachments(params[:attachments] || (params[:meeting] && params[:meeting][:uploads]))
    saved = false
    begin
      saved = @meeting.save_meeting_with_child_records(params, @time_entry)
    rescue ActiveRecord::StaleObjectError => e
      @conflict = true
      if params[:last_journal_id]
        @conflict_journals = @meeting.journals_after(params[:last_journal_id]).all
        @conflict_journals.reject!(&:private_notes?) unless User.current.allowed_to?(:view_private_notes, @meeting.project)
      end
    end
    if saved
      render_attachment_warning_if_needed(@meeting)
      flash[:notice] = l(:notice_successful_update) unless @meeting.current_journal.new_record?

      respond_to do |format|
        format.html { redirect_back_or_default({:action => 'show', :id => @meeting}) }
      end
    else
      respond_to do |format|
        format.html { render :action => 'edit' }
      end
    end
  end

  def index
    retrieve_query
    sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
    sort_update(@query.sortable_columns)
    @query.sort_criteria = sort_criteria.to_a

    if @query.valid?
      @limit = per_page_option
      
      @meeting_count = @query.meeting_count
      @meeting_pages = Paginator.new self, @meeting_count, @limit, params['page']
      @offset ||= @meeting_pages.current.offset
      @meetings = @query.meetings(#:order => sort_clause,
                              :offset => @offset,
                              :limit => @limit)
      @meeting_count_by_group = @query.meeting_count_by_group
    else
      respond_to do |format|
        format.html { render(:template => 'meetings/index', :layout => !request.xhr?) }
      end      
    end
  end

  def destroy
    begin
      @meeting.destroy      
      respond_to do |format|
        format.html { redirect_back_or_default(:action => 'index', :project_id => @project) }
      end
    rescue ActiveRecord::DeleteRestrictionError
      flash[:error] = l(:notice_meeting_with_time_entries)
      respond_to do |format|
        format.html { redirect_back_or_default(:action => 'show', :project_id => @project, :id => @meeting) }
      end
    end
  end
  
  def meetings
    @meetings = []
    q = (params[:q] || params[:term]).to_s.strip
    if q.present?
      scope = (params[:scope] == "all" || @project.nil? ? Meeting : @project.meetings).visible
    if q.match(/^\d+$/)
      @meetings << scope.find_by_id(q.to_i)
    end
    @meetings += scope.where("LOWER(#{Meeting.table_name}.subject) LIKE ?", "%#{q.downcase}%").order("#{Meeting.table_name}.id DESC").limit(10).all
      @meetings.compact!
    end
    render :layout => false
  end
  
  private
  
  def find_meeting
    @meeting = Meeting.find(params[:id])
  end
  
  def find_project
    project_id = params[:project_id] || (@meeting && @meeting.project_id)
    @project = Project.find(project_id)
  rescue ActiveRecord::RecordNotFound
    render_404 if project_id
  end
  
  def remove_date_in_hours_fields
    (1..3).each do |i|
      params[:meeting].delete("start_hour(#{i}i)") if params[:meeting]["start_hour(4i)"].blank? && params[:meeting]["start_hour(5i)"].blank?
      params[:meeting].delete("end_hour(#{i}i)") if params[:meeting]["end_hour(4i)"].blank? && params[:meeting]["end_hour(5i)"].blank?
    end
  end
  
  def update_meeting_from_params
    @edit_allowed = User.current.allowed_to?(:edit_meetings, @project)
    @time_entry = TimeEntry.new(:meeting => @meeting, :project => @meeting.project)
    @time_entry.attributes = params[:time_entry]

    @meeting.init_journal(User.current)

    meeting_attributes = params[:meeting]
    @meeting.safe_attributes = meeting_attributes
  end
end
