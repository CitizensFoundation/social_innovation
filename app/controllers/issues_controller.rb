class IssuesController < ApplicationController

  before_filter :get_tag_names, :except => :index
  before_filter :set_counts, :except => :index
  before_filter :check_for_user, :only => [:yours, :yours_finished, :yours_created, :network]

  def index
    @page_title =  tr("Categories", "controller/issues")
    #if request.format != 'html' or current_instance.tags_page == 'list'
    @categories = Category.all.collect { |category| t = Tag.filtered.find_by_name(category.name) }.select { |t| t != nil }
    @sub_instance_tags = []
    if current_sub_instance.required_tags
      sub_instance_tags = {}
      SubInstance.all.each do |sub_instance|
        sub_instance.required_tags.split(',').each do |tag|
          sub_instance_tags[tag] = true
        end
      end
      @sub_instance_tags = sub_instance_tags.keys.collect { |t| Tag.find_by_name(t) }
    end
    if default_tags and default_tags.length>1
      @issues = Tag.filtered.not_in_default_tags(@sub_instance_tags.collect { |t| t.slug }).not_in_default_tags(@categories.collect { |c| c.slug }).not_in_default_tags(default_tags).most_priorities.paginate(:page => params[:page], :per_page => params[:per_page])
    else
      @issues = Tag.filtered.not_in_default_tags(@sub_instance_tags.collect { |t| t.slug }).not_in_default_tags(@categories.collect { |c| c.slug }).most_priorities.paginate(:page => params[:page], :per_page => params[:per_page])
    end
    respond_to do |format|
      format.html {
        if current_instance.tags_page == 'cloud'
          render :template => "issues/cloud"
        elsif current_instance.tags_page == 'list'
          render :template => "issues/index"
        end
      }
      format.xml { render :xml => @issues.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @issues.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end    
  end

  def show
    if not @tag
      flash[:error] = tr("That {tags_name} doesn't exist anymore", "controller/issues", :tags_name => current_instance.tags_name.downcase)
      redirect_to "/" and return 
    end
    @page_title = tr("{tag_name} priorities", "controller/issues", :tag_name => tr(@tag_names, "model/category").titleize)
    @priorities = Priority.filtered.tagged_with(@tag_names, :on => :issues).published.top_rank.paginate(:page => params[:page], :per_page => params[:per_page])
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }            
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end    
  end

  alias :top :show

  def yours
    @page_title = tr("Your {tag_name} priorities", "controller/issues", :tag_name => tr(@tag_names, "model/category").titleize)
    @priorities = @user.priorities.tagged_with(@tag_names, :on => :issues).paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements if logged_in?
    respond_to do |format|
      format.html { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }           
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end   
  end

  def yours_finished
    @page_title = tr("Your finished {tag_name} priorities", "controller/issues", :tag_name => tr(@tag_names, "model/category").titleize)
    @priorities = @user.finished_priorities.finished.tagged_with(@tag_names, :on => :issues, :order => "priorities.status_changed_at desc").paginate :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }      
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end
  
  def yours_created
    @page_title = tr("{tag_name} priorities you created", "controller/issues", :tag_name => tr(@tag_names, "model/category").titleize)
    @priorities = @user.created_priorities.tagged_with(@tag_names, :on => :issues).paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements if logged_in?
    respond_to do |format|
      format.html { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }      
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end  
  
  def network
    @page_title = tr("Your network's {tag_name} priorities", "controller/issues", :tag_name => tr(@tag_names, "model/category").titleize)
    @tag_priorities = Priority.published.filtered.tagged_with(@tag_names, :on => :issues)
    if @user.followings_count > 0
      @priorities = Endorsement.active.find(:all, 
        :select => "endorsements.priority_id, sum((#{Endorsement.max_position+1}-endorsements.position)*endorsements.value) as score, count(*) as endorsements_number, priorities.*", 
        :joins => "endorsements INNER JOIN priorities ON priorities.id = endorsements.priority_id", 
        :conditions => ["endorsements.user_id in (?) and endorsements.position <= #{Endorsement.max_position} and endorsements.priority_id in (?)",@user.followings.up.collect{|f|f.other_user_id}, @tag_priorities.collect{|p|p.id}], 
        :group => "endorsements.priority_id",       
        :order => "score desc").paginate :page => params[:page]
        if logged_in?
          @endorsements = current_user.endorsements.active.find(:all, :conditions => ["priority_id in (?)", @priorities.collect {|c| c.priority_id}])
        end
    end
    respond_to do |format|
      format.html
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }         
      format.xml { render :xml => @priorities.to_xml(:include => :priority, :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:include => :priority, :except => NB_CONFIG['api_exclude_fields']) }
    end   
  end  

  def official
    @page_title = tr("{official_user_name} {tag_name} priorities", "controller/issues", :tag_name => tr(@tag_names, "model/category").titleize, :official_user_name => current_instance.official_user.name.possessive)
    @priorities = Priority.tagged_with(@tag_names, :on => :issues).published.official_endorsed.top_rank.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }          
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end  
  end
  
  def not_official
    @page_title = tr("{tag_name} priorities NOT on {official_user_name} agenda", "controller/issues", :tag_name => tr(@tag_names, "model/category").titleize, :official_user_name => current_instance.official_user.name.possessive)
    @priorities = Priority.tagged_with(@tag_names, :on => :issues).published.not_official.top_rank.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }          
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end   
  end
  
  def official_opposed
    @page_title = tr("{tag_name} priorities {official_user_name} opposes", "controller/issues", :tag_name => tr(@tag_names, "model/category").titleize, :official_user_name => current_instance.official_user.name)
    @priorities = Priority.tagged_with(@tag_names, :on => :issues).published.official_opposed.top_rank.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }          
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end  

  def rising
    @page_title = tr("Rising {tag_name} priorities", "controller/issues", :tag_name => tr(@tag_names, "model/category").titleize)
    @priorities = Priority.tagged_with(@tag_names, :on => :issues).published.rising.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }            
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end
  
  def falling
    @page_title = tr("Falling {tag_name} priorities", "controller/issues", :tag_name => tr(@tag_names, "model/category").titleize)
    @priorities = Priority.tagged_with(@tag_names, :on => :issues).falling.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }            
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end  

  def controversial
    @page_title = tr("Controversial {tag_name} priorities", "controller/issues", :tag_name => tr(@tag_names, "model/category").titleize)
    @priorities = Priority.tagged_with(@tag_names, :on => :issues).published.controversial.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }            
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end

  # this doesn't work in pgsql :(
  def random
    @page_title = tr("Random {tag_name} priorities", "controller/issues", :tag_name => tr(@tag_names, "model/category").titleize)
    if User.adapter == 'postgresql'
      flash[:error] = "This page doesn't work, sorry."
      redirect_to "/issues/" + @tag.slug
      return
    else
      @priorities = Priority.tagged_with(@tag_names, :on => :issues).published.paginate :order => "rand()", :page => params[:page], :per_page => params[:per_page]
    end
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }            
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end

  def finished
    @page_title = tr("Finished {tag_name} priorities", "controller/issues", :tag_name => tr(@tag_names, "model/category").titleize)
    @priorities = Priority.tagged_with(@tag_names, :on => :issues).finished.by_most_recent_status_change.paginate :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }            
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end    
  end

  def newest
    @page_title = tr("New {tag_name} priorities", "controller/issues", :tag_name => tr(@tag_names, "model/category").titleize)
    @priorities = Priority.tagged_with(@tag_names, :on => :issues).published.newest.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }            
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end
  
  def discussions
    @page_title = tr("Discussions on {tag_name}", "controller/issues", :tag_name => tr(@tag_names, "model/category").titleize)
    @priorities = Priority.tagged_with(@tag_names, :on => :issues)
    @activities = Activity.filtered.active.filtered.discussions.for_all_users.by_recently_updated.find(:all, :conditions => ["priority_id in (?)",@priorities.collect{|p| p.id}]).paginate :page => params[:page], :per_page => params[:per_page], :per_page => 10
    respond_to do |format|
      format.html
      format.xml { render :xml => @activities.to_xml(:include => :comments, :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @activities.to_json(:include => :comments, :except => NB_CONFIG['api_exclude_fields']) }
    end
  end

  def points
    @page_title = tr("{tag_name} points", "controller/issues", :tag_name => tr(@tag_names, "model/category").titleize)
    @priorities = Priority.filtered.tagged_with(@tag_names, :on => :issues)
    @points = Point.filtered.by_helpfulness.find(:all, :conditions => ["priority_id in (?)",@priorities.collect{|p| p.id}]).paginate :page => params[:page], :per_page => params[:per_page]
    @qualities = nil
    if logged_in? and @points.any? # pull all their qualities on the points shown
      @qualities = PointQuality.find(:all, :conditions => ["point_id in (?) and user_id = ? ", @points.collect {|c| c.id},current_user.id])
    end    
    respond_to do |format|
      format.html
      format.xml { render :xml => @points.to_xml(:include => [:priority,:other_priority], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @points.to_json(:include => [:priority,:other_priority], :except => NB_CONFIG['api_exclude_fields']) }
    end
  end
  
  def twitter
    @page_title = tr("What people are saying right now about {tag_name}", "controller/issues", :tag_name => tr(@tag_names, "model/category").titleize)
  end
  
  private

  def set_counts
    if @tag_names
      priorities = Priority.filtered.tagged_with(@tag_names, :on => :issues).published.only_ids
      @priorities_count = priorities.count
      @points_count = Point.filtered.by_helpfulness.count(:all, :conditions => ["priority_id in (?)",priorities.collect{|p| p.id}])
      @discussions_count = Activity.filtered.active.filtered.discussions.for_all_users.by_recently_updated.count(:all, :conditions => ["priority_id in (?)",priorities.collect{|p| p.id}])
    end
  end
  def get_tag_names
    @tag = Tag.find_by_slug(params[:slug])
    if not @tag
      flash[:error] = tr("That {tags_name} doesn't exist anymore", "controller/issues", :tags_name => current_instance.tags_name)
      redirect_to "/issues"
      return
    end
    @tag_names = @tag.name
  end  
  
  def get_endorsements
    @endorsements = nil
    if logged_in? # pull all their endorsements on the priorities shown
      @endorsements = Endorsement.find(:all, :conditions => ["priority_id in (?) and user_id = ? and status='active'", @priorities.collect {|c| c.id},current_user.id])
    end
  end
  
  def check_for_user
    if params[:user_id]
      @user = User.find(params[:user_id])
    elsif logged_in?
      @user = current_user
    else
      access_denied and return
    end
  end

  def default_tags
    if current_instance.default_tags_checkbox
      current_instance.default_tags_checkbox.split(",").map{|t| t.parameterize_full[0..60]}
    else
      [""]
    end
  end
end

