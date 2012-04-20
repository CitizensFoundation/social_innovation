require 'date'

class PrioritiesController < ApplicationController

  before_filter :login_required, :only => [:yours_finished, :yours_ads, :yours_top, :yours_lowest, :consider, :flag_inappropriate, :comment, :edit, :update, 
                                           :tag, :tag_save, :opposed, :endorsed, :destroy, :new]
  before_filter :admin_required, :only => [:bury, :successful, :compromised, :intheworks, :failed]
  before_filter :load_endorsement, :only => [:show, :show_feed, :activities, :endorsers, :opposers, :opposer_points, :endorser_points, :neutral_points, :everyone_points,
                                             :opposed_top_points, :endorsed_top_points, :points_overview, :top_points, :discussions, :everyone_points ]
  before_filter :check_for_user, :only => [:yours, :network, :yours_finished, :yours_created]

  before_filter :setup_filter_dropdown

  caches_action :index, :top, :top_24hr, :top_7days, :top_30days,
                :ads, :controversial, :rising, :newest, :finished, :show,
                :top_points, :discussions, :endorsers, :opposers, :activities,
                :if => proc {|c| c.do_action_cache?},
                :cache_path => proc {|c| c.action_cache_path},
                :expires_in => 5.minutes

  layout :get_layout

  # GET /priorities
  def index
    if params[:q] and request.xhr?
      @priorities = Priority.published.filtered.find(:all, :select => "priorities.name", :conditions => ["name LIKE ?", "%#{params[:q]}%"], :order => "endorsements_count desc")
    elsif current_instance.homepage != 'index' and current_instance.homepage.index("/")
      redirect_to :controller => current_instance.homepage
      return
    elsif current_instance.homepage != 'index'
      redirect_to :action => current_instance.homepage
      return
    else
      @issues = Tag.most_priorities.find(:all, :conditions => "tags.id <> 384 and priorities_count > 4", :include => :top_priority).paginate(:page => params[:page])
      if logged_in? 
        priority_ids = @issues.collect {|c| c.top_priority_id} + @issues.collect {|c| c.rising_priority_id} + @issues.collect {|c| c.controversial_priority_id}
        @endorsements = Endorsement.find(:all, :conditions => ["priority_id in (?) and user_id = ? and status='active'",priority_ids,current_user.id])      
      end
    end
    respond_to do |format|
      format.html
      format.js { 
        if not @priorities
          render :nothing => true
        else
          render :text => @priorities.collect{|p|p.name}.join("\n") 
        end
      }
    end
  end
  
  # GET /priorities/yours
  def yours
    @page_title = tr("Your priorities at {instance_name}", "controller/priorities", :instance_name => tr(current_instance.name,"Name from database"))
    @priorities = @user.endorsements.active.by_position.paginate :include => :priority, :page => params[:page], :per_page => params[:per_page]
    @rss_url = yours_priorities_url(:format => 'rss')
    respond_to do |format|
      format.html
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }      
      format.xml { render :xml => @priorities.to_xml(:include => [:priority], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:include => [:priority], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end
  
  # GET /priorities/yours_top
  def yours_top
    @page_title = tr("Your priorities ranked highest by {instance_name} members", "controller/priorities", :instance_name => tr(current_instance.name,"Name from database"))
    @priorities = current_user.endorsements.active.by_priority_position.paginate :include => :priority, :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html { render :action => "yours" }
      format.xml { render :xml => @endorsements.to_xml(:include => [:priority], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @endorsements.to_json(:include => [:priority], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end  
  
  # GET /priorities/yours_lowest
  def yours_lowest
    @page_title = tr("Your priorities ranked lowest by {instance_name} members", "controller/priorities", :instance_name => tr(current_instance.name,"Name from database"))
    @priorities = current_user.endorsements.active.by_priority_lowest_position.paginate :include => :priority, :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html { render :action => "yours" }
      format.xml { render :xml => @endorsements.to_xml(:include => [:priority], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @endorsements.to_json(:include => [:priority], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end  
  
  # GET /priorities/yours_created  
  def yours_created
    @page_title = tr("Priorities you created at {instance_name}", "controller/priorities", :instance_name => tr(current_instance.name,"Name from database"))
    @priorities = @user.created_priorities.published.top_rank.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }      
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end  

  # GET /priorities/network
  def network
    @page_title = tr("Your network's priorities", "controller/priorities", :instance_name => tr(current_instance.name,"Name from database"))
    @rss_url = network_priorities_url(:format => 'rss')
    if @user.followings_count > 0
      @priorities = Endorsement.active.find(:all, 
        :select => "endorsements.priority_id, sum((#{Endorsement.max_position+1}-endorsements.position)*endorsements.value) as score, count(*) as endorsements_number, priorities.*", 
        :joins => "endorsements INNER JOIN priorities ON priorities.id = endorsements.priority_id", 
        :conditions => ["endorsements.user_id in (?) and endorsements.position <= #{Endorsement.max_position}",@user.followings.up.collect{|f|f.other_user_id}], 
        :group => "endorsements.priority_id",       
        :order => "score desc").paginate :page => params[:page], :per_page => params[:per_page]
        @endorsements = @user.endorsements.active.find(:all, :conditions => ["priority_id in (?)", @priorities.collect {|c| c.priority_id}])
    end
    respond_to do |format|
      format.html
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }      
      format.xml { render :xml => @priorities.to_xml(:include => [:priority], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:include => [:priority], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end
  
  # GET /priorities/yours_finished
  def yours_finished
    @page_title = tr("Your priorities in progress at {instance_name}", "controller/priorities", :instance_name => tr(current_instance.name,"Name from database"))
    @priorities = @user.endorsements.finished.find(:all, :order => "priorities.status_changed_at desc", :include => :priority).paginate :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html { render :action => "yours" }
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }      
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
    if logged_in? and request.format == 'html' and current_user.unread_notifications_count > 0
      for n in current_user.received_notifications.all
        n.read! if n.class == NotificationPriorityFinished and n.unread?
      end    
    end
  end  

  # GET /priorities/ads
  def ads
    @page_title = tr("Ads running at {instance_name}", "controller/priorities", :instance_name => tr(current_instance.name,"Name from database"))
    @ads = Ad.filtered.active_first.paginate :include => [:user, :priority], :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html
      format.xml { render :xml => @ads.to_xml(:include => [:priority], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ads.to_json(:include => [:priority], :except => NB_CONFIG['api_exclude_fields']) }
    end
  end

  # GET /priorities/yours_ads
  def yours_ads
    @page_title = tr("Your ads", "controller/priorities", :instance_name => tr(current_instance.name,"Name from database"))
    @ads = current_user.ads.active_first.paginate :include => [:user, :priority], :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html
      format.xml { render :xml => @ads.to_xml(:include => [:priority], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ads.to_json(:include => [:priority], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end  

  # GET /priorities/consider
  def consider
    @page_title = tr("Priorities you should consider", "controller/priorities", :instance_name => tr(current_instance.name,"Name from database"))
    @priorities = current_user.recommend(25)
    if @priorities.empty?
      flash[:error] = tr("You need to endorse a few things before we can recommend other priorities for you to consider. Here are a few random priorities to get started.", "controller/priorities")
      redirect_to :action => "random"
      return
    end
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.rss { render :action => "list" }
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end    
  end

  # GET /priorities/official
  def official
    @page_title = tr("{official_user_name} priorities", "controller/priorities", :instance_name => tr(current_instance.name,"Name from database"), :official_user_name => current_instance.official_user.name.possessive)
    @rss_url = official_priorities_url(:format => 'rss')   
    @priorities = Priority.published.filtered.official_endorsed.top_rank.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }            
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end
  
  # GET /priorities/official_opposed  
  def official_opposed
    @page_title = tr("Priorities {official_user_name} opposes", "controller/priorities", :instance_name => tr(current_instance.name,"Name from database"), :official_user_name => current_instance.official_user.name)
    @rss_url = official_opposed_priorities_url(:format => 'rss')       
    @priorities = Priority.published.filtered.official_opposed.top_rank.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }            
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end  
  
  # GET /priorities/not_official  
  def not_official
    @page_title = tr("Priorities NOT on {official_user_name} agenda", "controller/priorities", :instance_name => tr(current_instance.name,"Name from database"), :official_user_name => current_instance.official_user.name.possessive)
    @rss_url = not_official_priorities_url(:format => 'rss')       
    @priorities = Priority.published.filtered.not_official.top_rank.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }            
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end 
  end  

  # GET /priorities/top
  def top
    @page_title = tr("Top priorities", "controller/priorities")
    @rss_url = top_priorities_url(:format => 'rss')   
    @priorities = Priority.published.filtered.top_rank.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }      
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end

  # GET /priorities/top_24hr
  def top_24hr
    @page_title = tr("Top priorities past 24 hours", "controller/priorities")
    @rss_url = top_priorities_url(:format => 'rss')   
    @priorities = Priority.published.filtered.top_24hr.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }      
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end

  # GET /priorities/top_7days
  def top_7days
    @page_title = tr("Top priorities past 7 days", "controller/priorities")
    @rss_url = top_priorities_url(:format => 'rss')   
    @priorities = Priority.published.filtered.top_7days.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }      
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end

  # GET /priorities/top_30days
  def top_30days
    @page_title = tr("Top priorities past 30 days", "controller/priorities")
    @rss_url = top_priorities_url(:format => 'rss')   
    @priorities = Priority.published.filtered.top_30days.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }      
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end

  # GET /priorities/rising
  def rising
    @page_title = tr("Priorities rising in the rankings", "controller/priorities")
    @rss_url = rising_priorities_url(:format => 'rss')           
    @priorities = Priority.published.filtered.rising.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end
  
  # GET /priorities/falling
  def falling
    @page_title = tr("Priorities falling in the rankings", "controller/priorities")
    @rss_url = falling_priorities_url(:format => 'rss')
    @priorities = Priority.published.filtered.falling.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }    
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end  
  
  # GET /priorities/controversial  
  def controversial
    @page_title = tr("Most controversial priorities", "controller/priorities")
    @rss_url = controversial_priorities_url(:format => 'rss')       
    @priorities = Priority.published.filtered.controversial.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end
  
  # GET /priorities/finished
  def finished
    @page_title = tr("Priorities in progress", "controller/priorities")
    @rss_url = finished_priorities_url(:format => 'rss')
    @priorities = Priority.finished.not_deleted.by_most_recent_status_change.paginate :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html { render :action => "list" }
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }      
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end    
  end  
  
  # GET /priorities/random
  def random
    @page_title = tr("Random priorities", "controller/priorities")
    if User.adapter == 'postgresql'
      @priorities = Priority.published.filtered.paginate :order => "RANDOM()", :page => params[:page], :per_page => params[:per_page]
    else
      @priorities = Priority.published.filtered.paginate :order => "rand()", :page => params[:page], :per_page => params[:per_page]
    end
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }      
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end

  # GET /priorities/newest
  def newest
    @page_title = tr("Newest priorities", "controller/priorities")
    @rss_url = newest_priorities_url(:format => 'rss')     
    @priorities = Priority.published.filtered.newest.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'priorities/list_widget_small')) + "');" }      
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end    
  end
  
  # GET /priorities/untagged
  def untagged
    @page_title = tr("Untagged (or uncategorized) priorities", "controller/priorities")
    @rss_url = untagged_priorities_url(:format => 'rss')            
    @priorities = Priority.published.filtered.untagged.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.rss { render :action => "list" }
      format.xml { render :xml => @priorities.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priorities.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end  
  end  
  
  # GET /priorities/1
  def show
    @page_title = @priority.name
    @show_only_last_process = false
    @point_value = 0
    @points_top_up = @priority.points.published.by_helpfulness.up_value.five
    @points_top_down = @priority.points.published.by_helpfulness.down_value.five
    @points_new_up = @priority.points.published.by_recently_created.up_value.five.reject {|p| @points_top_up.include?(p)}
    @points_new_down = @priority.points.published.by_recently_created.down_value.five.reject {|p| @points_top_down.include?(p)}
    @total_up_points = @priority.points.published.up_value.count
    @total_down_points = @priority.points.published.down_value.count
    @total_up_points_new = [0,@total_up_points-@points_top_up.length].max
    @total_down_points_new = [0,@total_down_points-@points_top_down.length].max
    get_qualities([@points_new_up,@points_new_down,@points_top_up,@points_top_down])

    @activities = @priority.activities.active.top_discussions.for_all_users :include => :user
    if logged_in? and @endorsement
      if @endorsement.is_up?
        @relationships = @priority.relationships.endorsers_endorsed.by_highest_percentage.find(:all, :include => :other_priority).group_by {|o|o.other_priority}
      elsif @endorsement.is_down?
        @relationships = @priority.relationships.opposers_endorsed.by_highest_percentage.find(:all, :include => :other_priority).group_by {|o|o.other_priority}
      end
    else
      @relationships = @priority.relationships.who_endorsed.by_highest_percentage.find(:all, :include => :other_priority).group_by {|o|o.other_priority}
    end
    @endorsements = nil
    if logged_in? # pull all their endorsements on the priorities shown
      @endorsements = Endorsement.find(:all, :conditions => ["priority_id in (?) and user_id = ? and status='active'", @relationships.collect {|other_priority, relationship| other_priority.id},current_user.id])
    end    
    respond_to do |format|
      format.html { render :action => "show_with_processes" }
      format.xml { render :xml => @priority.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @priority.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end

  def show_feed
    last = params[:last].blank? ? Time.now + 1.second : Time.parse(params[:last])
    @activities = @priority.activities.active.top_discussions.feed(last).for_all_users :include => :user
    respond_to do |format|
      format.js
    end
  end

  def opposer_points
    @page_title = tr("Points opposing {priority_name}", "controller/priorities", :priority_name => @priority.name)
    @point_value = -1  
    @points = @priority.points.published.by_opposer_helpfulness.paginate :page => params[:page], :per_page => params[:per_page]
    get_qualities
    respond_to do |format|
      format.html { render :action => "points" }
      format.xml { render :xml => @points.to_xml(:include => [:priority, :other_priority], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @points.to_json(:include => [:priority, :other_priority], :except => NB_CONFIG['api_exclude_fields']) }
    end
  end
  
  def endorser_points
    @page_title = tr("Points supporting {priority_name}", "controller/priorities", :priority_name => @priority.name)
    @point_value = 1
    @points = @priority.points.published.by_endorser_helpfulness.paginate :page => params[:page], :per_page => params[:per_page]
    get_qualities
    respond_to do |format|
      format.html { render :action => "points" }
      format.xml { render :xml => @points.to_xml(:include => [:priority, :other_priority], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @points.to_json(:include => [:priority, :other_priority], :except => NB_CONFIG['api_exclude_fields']) }
    end
  end
  
  def neutral_points
    @page_title = tr("Points about {priority_name}", "controller/priorities", :priority_name => @priority.name) 
    @point_value = 2 
    @points = @priority.points.published.by_neutral_helpfulness.paginate :page => params[:page], :per_page => params[:per_page]
    get_qualities
    respond_to do |format|
      format.html { render :action => "points" }
      format.xml { render :xml => @points.to_xml(:include => [:priority, :other_priority], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @points.to_json(:include => [:priority, :other_priority], :except => NB_CONFIG['api_exclude_fields']) }
    end
  end  
  
  def everyone_points
    @page_title = tr("Best points on {priority_name}", "controller/priorities", :priority_name => @priority.name) 
    @point_value = 0 
    @points = @priority.points.published.by_helpfulness.paginate :page => params[:page], :per_page => params[:per_page]
    get_qualities
    respond_to do |format|
      format.html { render :action => "points" }
      format.xml { render :xml => @points.to_xml(:include => [:priority, :other_priority], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @points.to_json(:include => [:priority, :other_priority], :except => NB_CONFIG['api_exclude_fields']) }
    end
  end  

  def opposed_top_points
    @page_title = tr("Points opposing {priority_name}", "controller/priorities", :priority_name => @priority.name)
    @point_value = -1
    if params[:by_newest]
      @points = @priority.points.published.down_value.by_recently_created.paginate :page => params[:page], :per_page => params[:per_page]
    else
      @points = @priority.points.published.down_value.by_helpfulness.paginate :page => params[:page], :per_page => params[:per_page]
    end
    get_qualities
    respond_to do |format|
      format.html { render :action => "points" }
      format.xml { render :xml => @points.to_xml(:include => [:priority, :other_priority], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @points.to_json(:include => [:priority, :other_priority], :except => NB_CONFIG['api_exclude_fields']) }
    end
  end
  
  def endorsed_top_points
    @page_title = tr("Points supporting {priority_name}", "controller/priorities", :priority_name => @priority.name)
    @point_value = 1
    if params[:by_newest]
      @points = @priority.points.published.up_value.by_recently_created.paginate :page => params[:page], :per_page => params[:per_page]
    else
      @points = @priority.points.published.up_value.by_helpfulness.paginate :page => params[:page], :per_page => params[:per_page]
    end
    get_qualities
    respond_to do |format|
      format.html { render :action => "points" }
      format.xml { render :xml => @points.to_xml(:include => [:priority, :other_priority], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @points.to_json(:include => [:priority, :other_priority], :except => NB_CONFIG['api_exclude_fields']) }
    end
  end

  def points_overview
    render :partial=>"priorities/points_overview_for", :layout=>false
  end

  def top_points
    @page_title = tr("Top points", "controller/priorities", :priority_name => @priority.name) 
    @point_value = 0 
    @points_top_up = @priority.points.published.by_helpfulness.up_value.five
    @points_top_down = @priority.points.published.by_helpfulness.down_value.five
    @points_new_up = @priority.points.published.by_recently_created.up_value.five.reject {|p| @points_top_up.include?(p)}
    @points_new_down = @priority.points.published.by_recently_created.down_value.five.reject {|p| @points_top_down.include?(p)}
    @total_up_points = @priority.points.published.up_value.count
    @total_down_points = @priority.points.published.down_value.count
    @total_up_points_new = [0,@total_up_points-@points_top_up.length].max
    @total_down_points_new = [0,@total_down_points-@points_top_down.length].max
    get_qualities([@points_new_up,@points_new_down,@points_top_up,@points_top_down])
    respond_to do |format|
      format.html { render :action => "top_points" }
      format.xml { render :xml => @points.to_xml(:include => [:priority, :other_priority], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @points.to_json(:include => [:priority, :other_priority], :except => NB_CONFIG['api_exclude_fields']) }
    end
  end  
  
  def points
    redirect_to :action => "everyone_points"
  end
  
  def discussions
    @page_title = tr("Discussions on {priority_name}", "controller/priorities", :priority_name => @priority.name) 
    @activities = @priority.activities.active.discussions.by_recently_updated.for_all_users.paginate :page => params[:page], :per_page => 10
    if @activities.empty? # pull all activities if there are no discussions
      @activities = @priority.activities.active.paginate :page => params[:page]
    end
    respond_to do |format|
      format.html { render :action => "activities" }
      format.xml { render :xml => @activities.to_xml(:include => :comments, :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @activities.to_json(:include => :comments, :except => NB_CONFIG['api_exclude_fields']) }
    end
  end  
  
  def comments
    @priority = Priority.find(params[:id])  
    @page_title = tr("Latest comments on {priority_name}", "controller/priorities", :priority_name => @priority.name) 
    @comments = Comment.published.by_recently_created.find(:all, :conditions => ["activities.priority_id = ?",@priority.id], :include => :activity).paginate :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html
      format.rss { render :template => "rss/comments" }
      format.xml { render :xml => @comments.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @comments.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end    
  end
  
  # GET /priorities/1/activities
  def activities
    @page_title = tr("Activity on {priority_name}", "controller/priorities", :priority_name => @priority.name) 
    @activities = @priority.activities.active.for_all_users.by_recently_created.paginate :include => :user, :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html
      format.rss { render :template => "rss/activities" }
      format.xml { render :xml => @activities.to_xml(:include => :comments, :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @activities.to_json(:include => :comments, :except => NB_CONFIG['api_exclude_fields']) }
    end
  end 
  
  # GET /priorities/1/endorsers
  def endorsers
    @page_title = tr("{number} people endorse {priority_name}", "controller/priorities", :priority_name => @priority.name, :number => @priority.up_endorsements_count)
    if request.format != 'html'
      @endorsements = @priority.endorsements.active_and_inactive.endorsing.paginate :page => params[:page], :per_page => params[:per_page], :include => :user
    end
    respond_to do |format|
      format.html
      format.xml { render :xml => @endorsements.to_xml(:include => :user, :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @endorsements.to_json(:include => :user, :except => NB_CONFIG['api_exclude_fields']) }      
    end
  end

  # GET /priorities/1/opposers
  def opposers
    @page_title = tr("{number} people opposed {priority_name}", "controller/priorities", :priority_name => @priority.name, :number => @priority.down_endorsements_count)
    if request.format != 'html'
      @endorsements = @priority.endorsements.active_and_inactive.opposing.paginate :page => params[:page], :per_page => params[:per_page], :include => :user
    end
    respond_to do |format|
      format.html
      format.xml { render :xml => @endorsements.to_xml(:include => :user, :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @endorsements.to_json(:include => :user, :except => NB_CONFIG['api_exclude_fields']) }      
    end
  end

  # GET /priorities/new
  # GET /priorities/new.xml
  def new
    @priority = Priority.new unless @priority
    @priority.points.build

    if @priorities
      @endorsements = Endorsement.find(:all, :conditions => ["priority_id in (?) and user_id = ? and status='active'", @priorities.collect {|c| c.id},current_user.id])
    end    

    respond_to do |format|
      format.html # new.html.erb
    end
  end

  # GET /priorities/1/edit
  def edit
    @priority = Priority.find(params[:id])
    @page_name = tr("Edit {priority_name}", "controller/priorities", :priority_name => @priority.name)
    if not (current_user.id == @priority.user_id and @priority.endorsements_count < 2) and not current_user.is_admin?
      flash[:error] = tr("You cannot change a priority's name once other people have endorsed it.", "controller/priorities")
      redirect_to @priority and return
    end
    respond_to do |format|
      format.html # new.html.erb
    end    
  end
  
  # POST /priorities
  # POST /priorities.xml
  def create
    if not logged_in?
      flash[:notice] = tr("First you need to fill out this quick form and agree to the rules, then you can start adding your priorities.", "controller/priorities")
      session[:query] = params[:priority][:name] if params[:priority]
      access_denied
      return
    end
  
    Rails.logger.debug("Point character length: #{params[:priority][:points_attributes]["0"][:content].length} #{params[:priority][:name].length}")

    if current_sub_instance and current_sub_instance.required_tags and not params[:priority][:priority_type]
      # default to the first tag
      params[:priority][:priority_type] = current_sub_instance.required_tags.split(',')[0]
    end

    @priority = Priority.new(params[:priority])
    tags = []
    tags << "Betri hverfi" if current_sub_instance and Instance.current.layout=="better_reykjavik"
    tags << @priority.category.name if @priority.category
    params.each do |p,v|
      tags << v if p.include?("special_checkbox_tag_")
    end
    params.each do |a,b|
      tags << b if a.include?("sub_tag_")
    end
    tags += params[:custom_tags].split(",").collect {|t| t.strip} if params[:custom_tags] and params[:custom_tags]!=""

    if current_sub_instance
      tags << current_sub_instance.name
      if current_sub_instance.required_tags
        tags << params[:priority][:priority_type]
      end
    end

    unless tags.empty?
      @priority.issue_list = tags.join(",")
    end
    @priority.user = current_user
    @priority.ip_address = request.remote_ip
    @priority.request = request
    @saved = @priority.save
    
    if @saved
      first_point = @priority.points.first
      first_point.setup_revision
      first_point.reload
      @endorsement = @priority.endorse(current_user,request,current_sub_instance,@referral)
      quality = first_point.point_qualities.find_or_create_by_user_id_and_value(current_user.id, true)
      if current_user.endorsements_count > 24
        session[:endorsement_page] = (@endorsement.position/25).to_i+1
        session[:endorsement_page] -= 1 if @endorsement.position == (session[:endorsement_page]*25)-25
      end    
    else
      # see if it already exists
      query = params[:priority][:name].strip
      same_name_priority = Priority.find(:first, :conditions => ["name = ? and status = 'published'", query], :order => "endorsements_count desc")
      flash[:current_same_name_priority_id] = same_name_priority.id if same_name_priority
    end
    
    respond_to do |format|
      if @saved
        format.html { 
          flash[:notice] = tr("Thanks for adding {priority_name}", "controller/priorities", :priority_name => @priority.name)
          redirect_to(@priority)
        }
        format.js {
          render :update do |page|
            page.redirect_to @priority
          end
        }        
      else
        format.html { render :controller => "priorities", :action => "new", :notice=>flash[:notice] }
      end
    end
  end

  # POST /priorities/1/endorse
  def endorse
    @value = (params[:value]||1).to_i
    @priority = Priority.find(params[:id])
    if not logged_in?
      session[:priority_id] = @priority.id
      session[:value] = @value
      access_denied
      return
    end
    if @value == 1
      @endorsement = @priority.endorse(current_user,request,current_sub_instance,@referral)
    else
      @endorsement = @priority.oppose(current_user,request,current_sub_instance,@referral)
    end
    if params[:ad_id]    
      @ad = Ad.find(params[:ad_id])
      @ad.vote(current_user,@value,request) if @ad
    else
      @ad = Ad.find_by_priority_id_and_status(@priority.id,'active')
      if @ad and @ad.shown_ads.find_by_user_id(current_user.id)
        @ad.vote(current_user,@value,request) 
      end
    end
    if current_user.endorsements_count > 24
      session[:endorsement_page] = (@endorsement.position/25).to_i+1
      session[:endorsement_page] -= 1 if @endorsement.position == (session[:endorsement_page]*25)-25
    end
    @priority.reload
    respond_to do |format|
      format.js {
        render :update do |page|
          if params[:region] == 'priority_left'
            page.replace_html 'priority_' + @priority.id.to_s + "_button",render(:partial => "priorities/button", :locals => {:priority => @priority, :endorsement => @endorsement})
            page.replace_html 'priority_' + @priority.id.to_s + "_position",render(:partial => "endorsements/position", :locals => {:endorsement => @endorsement})            
            page.replace 'endorser_link', render(:partial => "priorities/endorser_link") 
            page.replace 'opposer_link', render(:partial => "priorities/opposer_link")
            if @value == 1          
              @activity = ActivityEndorsementNew.find_by_priority_id_and_user_id(@priority.id,current_user.id, :order => "created_at desc")
            else
              @activity = ActivityOppositionNew.find_by_priority_id_and_user_id(@priority.id,current_user.id, :order => "created_at desc")
            end            
            if @activity and not params[:no_activites]
              page.insert_html :top, 'activities', render(:partial => "activities/show", :locals => {:activity => @activity, :suffix => "_noself"})
            end
          elsif params[:region] == 'priority_subs'
            page.replace_html 'priority_' + @priority.id.to_s + "_button",render(:partial => "priorities/button_subs", :locals => {:priority => @priority, :endorsement => @endorsement})
            page.replace 'endorser_link', render(:partial => "priorities/endorser_link") 
            page.replace 'opposer_link', render(:partial => "priorities/opposer_link")
          elsif params[:region] == 'priority_inline'
            page<<"$('.priority_#{@priority.id.to_s}_button_small').replaceWith('#{escape_javascript(render(:partial => "priorities/button_small", :locals => {:priority => @priority, :endorsement => @endorsement, :region => params[:region]}))}')"
            page<<"$('.priority_#{@priority.id.to_s}_endorsement_count').replaceWith('#{escape_javascript(render(:partial => "priorities/endorsement_count", :locals => {:priority => @priority}))}')"
          elsif params[:region] == 'ad_top' and @ad
            page.replace 'encouragements', render(:partial => "ads/pick")
            #page << 'if (jQuery("#notification_show").length > 0) { jQuery("#notification_show").corners(); }'
          else
            page << "alert('error');"
          end
          page.replace_html 'your_priorities_container', :partial => "priorities/yours"
        end
      }
    end
  end

  # PUT /priorities/1
  # PUT /priorities/1.xml
  def update
    @priority = Priority.find(params[:id])
    @previous_name = @priority.name
    @page_name = tr("Edit {priority_name}", "controller/priorities", :priority_name => @priority.name)

    if params[:priority]
      if params[:priority][:priority_type] and current_sub_instance and current_sub_instance.required_tags
        required_tags = current_sub_instance.required_tags.split(',')
        issues = @priority.issue_list
        if not issues.include?(params[:priority][:priority_type])
          new_issues = issues - required_tags
          new_issues << params[:priority][:priority_type]
          @priority.issue_list = new_issues.join(',')
        end
      end
      if params[:priority]["finished_status_date(1i)"]
        # TODO: isn't there an easier way to do this?
        params[:priority][:finished_status_date] = Date.new(params[:priority].delete("finished_status_date(1i)").to_i, params[:priority].delete("finished_status_date(2i)").to_i, params[:priority].delete("finished_status_date(3i)").to_i)
      end
      if params[:priority][:category]
        old_category = @priority.category
        new_category = Category.find(params[:priority][:category])
        params[:priority][:category] = new_category
        current_issues = @priority.issue_list
        remove_issues = [old_category.name]
        add_issues = [new_category.name]
        new_issues = add_issues | (current_issues - remove_issues)
        params[:priority][:issue_list] = new_issues.join(',')
      end
      if params[:priority][:finished_status_message]
        change_log = @priority_status_changelog = PriorityStatusChangeLog.new(
            priority_id: @priority.id,
            date: params[:priority][:finished_status_date],
            content: params[:priority][:finished_status_message],
            subject: params[:priority][:finished_status_subject]
        )
        @priority_status_changelog.save
      end
      if params[:priority][:official_status] and params[:priority][:official_status].to_i != @priority.official_status
        @change_status = params[:priority][:official_status].to_i
        #params[:priority].delete(:official_status)
      end
    end
    respond_to do |format|
      if params[:priority][:name] and @priority.update_attributes(params[:priority]) and @previous_name != params[:priority][:name]
        # already renamed?
        @activity = ActivityPriorityRenamed.find_by_user_id_and_priority_id(current_user.id,@priority.id)
        if @activity
          @activity.update_attribute(:updated_at,Time.now)
        else
          @activity = ActivityPriorityRenamed.create(:user => current_user, :priority => @priority)
        end
        format.html {
          flash[:notice] = tr("Saved {priority_name}", "controller/priorities", :priority_name => @priority.name)
          redirect_to(@priority)
        }
        format.js {
          render :update do |page|
            page.select('#priority_' + @priority.id.to_s + '_edit_form').each {|item| item.remove}
            page.select('#activity_and_comments_' + @activity.id.to_s).each {|item| item.remove}
            page.insert_html :top, 'activities', render(:partial => "activities/show", :locals => {:activity => @activity, :suffix => "_noself"})
            page.replace_html 'priority_' + @priority.id.to_s + '_name', render(:partial => "priorities/name", :locals => {:priority => @priority})
            # page.visual_effect :highlight, 'priority_' + @priority.id.to_s + '_name'
          end
        }
      else
        format.html {
          if params[:priority][:finished_status_message]
            flash[:notice] = tr('Status updated with "{status_text}"', "controller/priorities", status_text: params[:priority][:finished_status_subject])
          end
          redirect_to(@priority)
        }
        format.js {
          render :update do |page|
            page.select('#priority_' + @priority.id.to_s + '_edit_form').each {|item| item.remove}
            page.insert_html :top, 'activities', render(:partial => "priorities/new_inline", :locals => {:priority => @priority})
            page['priority_name'].focus
          end
        }
      end
      @priority.reload

      if @change_status
        @priority.change_status!(@change_status)
        @priority.delay.deactivate_endorsements
      end
      if change_log
        @priority.create_status_update(change_log)
        User.delay.send_status_email(@priority.id, params[:priority][:official_status], params[:priority][:finished_status_date], params[:priority][:finished_status_subject], params[:priority][:finished_status_message])
      end
    end
  end

  # PUT /priorities/1/create_short_url
  def create_short_url
    @priority = Priority.find(params[:id])
    @short_url = @priority.create_short_url
    if @short_url
      @priority.save(:validate => false)
    end
    respond_to do |format|
      format.js {
        render :update do |page|
          page.replace "priority_short_url", render(:partial => "priorities/short_url", :locals => {:priority => @priority})
          page << "short_url.select();"
        end
      }
    end
  end

  # PUT /priorities/1/flag_inappropriate
  def flag
    @priority = Priority.find(params[:id])
    @priority.flag_by_user(current_user)

    respond_to do |format|
      format.html { redirect_to(comments_url) }
      format.js {
        render :update do |page|
          if current_user.is_admin?
            page.replace_html "priority_report_#{@priority.id}", render(:partial => "priorities/report_content", :locals => {:priority => @priority})
          else
            page.replace_html "priority_report_#{@priority.id}","<div class='warning_inline'> #{tr("Thanks for bringing this to our attention", "controller/priorities")}</div>"
          end
        end        
      }
    end    
  end  

  def abusive
    @priority = Priority.find(params[:id])
    @priority.do_abusive
    @priority.delete!
    respond_to do |format|
      format.js {
        render :update do |page|
          page.replace_html "priority_flag_#{@priority.id}", "<div class='warning_inline'>#{tr("The content has been deleted and a warning_sent", "controller/priorities")}</div>"
        end        
      }
    end    
  end

  def not_abusive
    @priority = Priority.find(params[:id])
    @priority.update_attribute(:flags_count, 0)
    respond_to do |format|
      format.js {
        render :update do |page|
          page.replace_html "priority_flag_#{@priority.id}",""
        end        
      }
    end    
  end
  
  # PUT /priorities/1/bury
  def bury
    @priority = Priority.find(params[:id])
    @priority.bury!
    ActivityPriorityBury.create(:priority => @priority, :user => current_user, :sub_instance => current_sub_instance)
    respond_to do |format|
      flash[:notice] = tr("{priority_name} is now buried, it will no longer be displayed in the charts.", "controller/priorities", :priority_name => @priority.name)
      format.html { redirect_to(@priority) }
    end
  end  
  
  # PUT /priorities/1/successful
  def successful
    @priority = Priority.find(params[:id])
    @priority.successful!
    respond_to do |format|
      flash[:notice] = tr("{priority_name} is now marked finished and successful", "controller/priorities", :priority_name => @priority.name)
      format.html { redirect_to(@priority) }
    end
  end  
  
  # PUT /priorities/1/intheworks
  def intheworks
    @priority = Priority.find(params[:id])
    @priority.intheworks!
    respond_to do |format|
      flash[:notice] = tr("{priority_name} is now marked 'in the works'", "controller/priorities", :priority_name => @priority.name)
      format.html { redirect_to(@priority) }
    end
  end  
  
  # PUT /priorities/1/failed
  def failed
    @priority = Priority.find(params[:id])
    @priority.failed!
    respond_to do |format|
      flash[:notice] = tr("{priority_name} is now marked finished and failed", "controller/priorities", :priority_name => @priority.name)
      format.html { redirect_to(@priority) }
    end
  end  
  
  # PUT /priorities/1/compromised
  def compromised
    @priority = Priority.find(params[:id])
    @priority.compromised!
    respond_to do |format|
      flash[:notice] = tr("{priority_name} is now marked finished but compromised", "controller/priorities", :priority_name => @priority.name)
      format.html { redirect_to(@priority) }
    end
  end  
  
  def endorsed
    @priority = Priority.find(params[:id])
    @endorsement = @priority.endorse(current_user,request,current_sub_instance,@referral)
    redirect_to @priority
  end

  def opposed
    @priority = Priority.find(params[:id])
    @endorsement = @priority.oppose(current_user,request,current_sub_instance,@referral)
    redirect_to @priority    
  end

  # GET /priorities/1/tag
  def tag
    @priority = Priority.find(params[:id])
    respond_to do |format|
      format.js {
        render :update do |page|
          page.replace_html 'priority_' + @priority.id.to_s + '_tags', render(:partial => "priorities/tag", :locals => {:priority => @priority})
          page['priority_' + @priority.id.to_s + "_issue_list"].focus          
        end        
      }
    end
  end

  # POST /priorities/1/tag
  def tag_save
    @priority = Priority.find(params[:id])
    @priority.update_attributes(params[:priority])    
    respond_to do |format|
      format.js {
        render :update do |page|
          page.replace_html 'priority_' + @priority.id.to_s + '_tags', render(:partial => "priorities/tag_show", :locals => {:priority => @priority}) 
        end        
      }
    end
  end
  
  # DELETE /priorities/1
  def destroy
    if current_user.is_admin?
      @priority = Priority.find(params[:id])
    else
      @priority = current_user.created_priorities.find(params[:id])
    end
    return unless @priority
    name = @priority.name
    @priority.delete!
    flash[:notice] = tr("Permanently deleting {priority_name}. This may take a few minutes depending on how many endorsements/oppositions need to be removed.", "controller/priorities", :priority_name => name)
    respond_to do |format|
      format.html { redirect_to yours_created_priorities_url }    
    end
  end

  def update_status
    @priority = Priority.find(params[:id])
    @page_name = tr("Edit the status of {priority_name}", "controller/priorities", :priority_name => @priority.name)
    if not current_user.is_admin?
      flash[:error] = tr("You cannot change a priority's name once other people have endorsed it.", "controller/priorities")
      redirect_to @priority and return
    end
    respond_to do |format|
      format.html
    end
  end

  private
  
    def get_endorsements
      @endorsements = nil
      if logged_in? # pull all their endorsements on the priorities shown
        @endorsements = current_user.endorsements.active.find(:all, :conditions => ["priority_id in (?)", @priorities.collect {|c| c.id}])
      end
    end
    
    def load_endorsement
      @priority = Priority.find(params[:id])
      if @priority.status == 'deleted' or @priority.status == 'abusive'
        flash[:notice] = tr("That priority was deleted", "controller/priorities")
        redirect_to "/"
        return false
      end

      @endorsement = nil
      if logged_in? # pull all their endorsements on the priorities shown
        @endorsement = @priority.endorsements.active.find_by_user_id(current_user.id)
      end
    end    

    def get_qualities(multi_points=nil)
      if multi_points
        @points=[]
        multi_points.each do |points|
          @points+=points
        end
      end
      if not @points.empty?
        @qualities = nil
        if logged_in? # pull all their qualities on the priorities shown
          @qualities = PointQuality.find(:all, :conditions => ["point_id in (?) and user_id = ? ", @points.collect {|c| c.id},current_user.id])
        end      
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

  def setup_menu_items
    @items = Hash.new
    @items[1]=[tr("Top All", "view/priorities/_browse_nav"), top_priorities_url]
    @items[2]=[tr("Top Active 24 hours", "view/priorities/_browse_nav"), top_24hr_priorities_url]
    @items[3]=[tr("Top Active 7 days", "view/priorities/_browse_nav"), top_7days_priorities_url]
    @items[4]=[tr("Top Active 30 days", "view/priorities/_browse_nav"), top_30days_priorities_url]
    @items[6]=[tr("New", "view/priorities/_browse_nav"), newest_priorities_url]
    @items[8]=[tr("Random", "view/priorities/_browse_nav"), random_priorities_url]
    @items[9]=[tr("In Progress", "view/priorities/_browse_nav"), finished_priorities_url]
    @items[10]=[tr("Controversial", "view/priorities/_browse_nav"), controversial_priorities_url]
    @items[11]=[tr("Ads", "view/priorities/_browse_nav"), ads_priorities_url]
    @items[12]=[tr("Rising", "view/priorities/_browse_nav"), rising_priorities_url]
    @items[13]=[tr("Falling", "view/priorities/_browse_nav"), rising_priorities_url]
    if logged_in?
      @items[14]=[tr("Your network", "view/priorities/_browse_nav"), network_priorities_url]
      @items[15]=[tr("Yours", "view/priorities/_browse_nav"), yours_priorities_url]
    end
    @items
  end
end
