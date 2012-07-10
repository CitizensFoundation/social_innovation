class IssuesController < ApplicationController

  #before_filter :get_tag_names, :except => :index
  #before_filter :set_counts, :except => :index
  before_filter :check_for_user, :only => [:yours, :yours_finished, :yours_created, :network]
  before_filter :setup_filter_dropdown

  def index
    @page_title =  tr("Categories", "controller/issues")
    @categories = Category.all
    #@categories = Category.all.collect { |category| t = Tag.find_by_name(category.name) }.select { |t| t != nil }
    #@sub_instance_tags = []
    #if current_sub_instance.required_tags
    #  sub_instance_tags = {}
    #  SubInstance.all.each do |sub_instance|
    #    sub_instance.required_tags.split(',').each do |tag|
    #      sub_instance_tags[tag] = true
    #    end
    #  end
    #  @sub_instance_tags = sub_instance_tags.keys.collect { |t| Tag.find_by_name(t) }
    #end
    #if default_tags and default_tags.length>1
    #  @issues = Tag.not_in_default_tags(@sub_instance_tags.collect { |t| t.slug }).not_in_default_tags(@categories.collect { |c| c.slug }).not_in_default_tags(default_tags).most_ideas.paginate(:page => params[:page], :per_page => params[:per_page])
    #else
    #  @issues = Tag.not_in_default_tags(@sub_instance_tags.collect { |t| t.slug }).not_in_default_tags(@categories.collect { |c| c.slug }).most_ideas.paginate(:page => params[:page], :per_page => params[:per_page])
    #end
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
    #if not @tag
    #  flash[:error] = tr("That {tags_name} doesn't exist anymore", "controller/issues", :tags_name => current_instance.tags_name.downcase)
    #  redirect_to "/" and return
    #end
    @category = Category.find(params[:id])
    @page_title = tr("{tag_name} ideas", "controller/issues", :tag_name => tr(@category.name, "model/category").titleize)
    @ideas = Idea.where(category_id: @category.id).published.top_rank.paginate(:page => params[:page], :per_page => params[:per_page])
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'ideas/list_widget_small')) + "');" }
      format.xml { render :xml => @ideas.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end    
  end

  alias :top :show

  def yours
    @category = Category.find(params[:id])
    @page_title = tr("Your {tag_name} ideas", "controller/issues", :tag_name => tr(@category.name, "model/category").titleize)
    @ideas = @user.ideas.where(category_id: @category.id).paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements if logged_in?
    respond_to do |format|
      format.html { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'ideas/list_widget_small')) + "');" }
      format.xml { render :xml => @ideas.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end   
  end

  def yours_finished
    @category = Category.find(params[:id])
    @page_title = tr("Your finished {tag_name} ideas", "controller/issues", :tag_name => tr(@category.name, "model/category").titleize)
    @ideas = @user.finished_ideas.finished.where(category_id: @category.id).order("ideas.status_changed_at desc").paginate :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'ideas/list_widget_small')) + "');" }
      format.xml { render :xml => @ideas.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end
  
  def yours_created
    @category = Category.find(params[:id])
    @page_title = tr("{tag_name} ideas you created", "controller/issues", :tag_name => tr(@category.name, "model/category").titleize)
    @ideas = @user.created_ideas.where(category_id: @category.id).paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements if logged_in?
    respond_to do |format|
      format.html { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'ideas/list_widget_small')) + "');" }
      format.xml { render :xml => @ideas.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end  
  
  def network
    @category = Category.find(params[:id])
    @page_title = tr("Your network's {tag_name} ideas", "controller/issues", :tag_name => tr(@category.name, "model/category").titleize)
    @tag_ideas = Idea.published.where(category_id: @category.id)
    if @user.followings_count > 0
      @ideas = Endorsement.active.find(:all,
        :select => "endorsements.idea_id, sum((#{Endorsement.max_position+1}-endorsements.position)*endorsements.value) as score, count(*) as endorsements_number, ideas.*",
        :joins => "endorsements INNER JOIN ideas ON ideas.id = endorsements.idea_id",
        :conditions => ["endorsements.user_id in (?) and endorsements.position <= #{Endorsement.max_position} and endorsements.idea_id in (?)",@user.followings.up.collect{|f|f.other_user_id}, @tag_ideas.collect{|p|p.id}],
        :group => "endorsements.idea_id",
        :order => "score desc").paginate :page => params[:page]
        if logged_in?
          @endorsements = current_user.endorsements.active.find(:all, :conditions => ["idea_id in (?)", @ideas.collect {|c| c.idea_id}])
        end
    end
    respond_to do |format|
      format.html
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'ideas/list_widget_small')) + "');" }
      format.xml { render :xml => @ideas.to_xml(:include => :idea, :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:include => :idea, :except => NB_CONFIG['api_exclude_fields']) }
    end   
  end

  def rising
    @category = Category.find(params[:id])
    @page_title = tr("Rising {tag_name} ideas", "controller/issues", :tag_name => tr(@category.name, "model/category").titleize)
    @ideas = Idea.where(category_id: @category.id).published.rising.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'ideas/list_widget_small')) + "');" }
      format.xml { render :xml => @ideas.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end
  
  def falling
    @category = Category.find(params[:id])
    @page_title = tr("Falling {tag_name} ideas", "controller/issues", :tag_name => tr(@category.name, "model/category").titleize)
    @ideas = Idea.where(category_id: @category.id).falling.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'ideas/list_widget_small')) + "');" }
      format.xml { render :xml => @ideas.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end  

  def controversial
    @category = Category.find(params[:id])
    @page_title = tr("Controversial {tag_name} ideas", "controller/issues", :tag_name => tr(@category.name, "model/category").titleize)
    @ideas = Idea.where(category_id: @category.id).published.controversial.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'ideas/list_widget_small')) + "');" }
      format.xml { render :xml => @ideas.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end

  # this doesn't work in pgsql :(
  def random
    @category = Category.find(params[:id])
    @page_title = tr("Random {tag_name} ideas", "controller/issues", :tag_name => tr(@category.name, "model/category").titleize)
    if User.adapter == 'postgresql'
      flash[:error] = "This page doesn't work, sorry."
      redirect_to "/issues/" + @tag.slug
      return
    else
      @ideas = Idea.where(category_id: @category).published.paginate :order => "rand()", :page => params[:page], :per_page => params[:per_page]
    end
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'ideas/list_widget_small')) + "');" }
      format.xml { render :xml => @ideas.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end

  def finished
    @category = Category.find(params[:id])
    @page_title = tr("Finished {tag_name} ideas", "controller/issues", :tag_name => tr(@category.name, "model/category").titleize)
    @ideas = Idea.where(category_id: @category.id).finished.by_most_recent_status_change.paginate :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'ideas/list_widget_small')) + "');" }
      format.xml { render :xml => @ideas.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end    
  end

  def newest
    @category = Category.find(params[:id])
    @page_title = tr("New {tag_name} ideas", "controller/issues", :tag_name => tr(@category.name, "model/category").titleize)
    @ideas = Idea.where(category_id: @category.id).published.newest.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'ideas/list_widget_small')) + "');" }
      format.xml { render :xml => @ideas.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end
  
  def discussions
    @category = Category.find(params[:id])
    @page_title = tr("Discussions on {tag_name}", "controller/issues", :tag_name => tr(@category.name, "model/category").titleize)
    @ideas = Idea.where(category_id: @category.id)
    @activities = Activity.active.discussions.for_all_users.by_recently_updated.find(:all, :conditions => ["idea_id in (?)",@ideas.collect{|p| p.id}]).paginate :page => params[:page], :per_page => params[:per_page], :per_page => 10
    respond_to do |format|
      format.html
      format.xml { render :xml => @activities.to_xml(:include => :comments, :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @activities.to_json(:include => :comments, :except => NB_CONFIG['api_exclude_fields']) }
    end
  end

  def points
    @category = Category.find(params[:id])
    @page_title = tr("{tag_name} points", "controller/issues", :tag_name => tr(@category.name, "model/category").titleize)
    @ideas = Idea.where(category_id: @category.id)
    @points = Point.by_helpfulness.find(:all, :conditions => ["idea_id in (?)",@ideas.collect{|p| p.id}]).paginate :page => params[:page], :per_page => params[:per_page]
    @qualities = nil
    if logged_in? and @points.any? # pull all their qualities on the points shown
      @qualities = PointQuality.find(:all, :conditions => ["point_id in (?) and user_id = ? ", @points.collect {|c| c.id},current_user.id])
    end    
    respond_to do |format|
      format.html
      format.xml { render :xml => @points.to_xml(:include => [:idea,:other_idea], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @points.to_json(:include => [:idea,:other_idea], :except => NB_CONFIG['api_exclude_fields']) }
    end
  end
  
  def twitter
    @page_title = tr("What people are saying right now about {tag_name}", "controller/issues", :tag_name => tr(@tag_names, "model/category").titleize)
  end
  
  private

  def setup_menu_items
    @items ||= begin
      items = Hash.new
      categories = Category.all.collect { |category| t = Tag.find_by_name(category.name) }.select { |t| t != nil }
      categories.each_with_index do |category, idx|
        items[idx] = [tr(category.name, "model/category"), issue_url(category.slug)]
      end
      Rails.logger.debug "FOOBAR"
      Rails.logger.debug items.inspect
      items
    end
  end

  def set_counts
    if @tag_names
      ideas = Idea.tagged_with(@tag_names, :on => :issues).published.only_ids
      @ideas_count = ideas.count
      @points_count = Point.by_helpfulness.count(:all, :conditions => ["idea_id in (?)",ideas.collect{|p| p.id}])
      @discussions_count = Activity.active.discussions.for_all_users.by_recently_updated.count(:all, :conditions => ["idea_id in (?)",ideas.collect{|p| p.id}])
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
    if logged_in? # pull all their endorsements on the ideas shown
      @endorsements = Endorsement.find(:all, :conditions => ["idea_id in (?) and user_id = ? and status='active'", @ideas.collect {|c| c.id},current_user.id])
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

