require 'date'

class IdeasController < ApplicationController
  before_filter :login_required, :only => [:yours_finished, :yours_ads, :yours_top, :yours_lowest, :consider, :flag_inappropriate, :comment, :edit, :update, 
                                           :tag, :tag_save, :opposed, :endorsed, :destroy, :new]
  before_filter :admin_required, :only => [:bury, :successful, :compromised, :intheworks, :failed]
  before_filter :load_endorsement, :only => [:show, :show_feed, :activities, :endorsers, :opposers, :opposer_points, :endorser_points, :neutral_points, :everyone_points,
                                             :opposed_top_points, :endorsed_top_points, :idea_detail, :top_points, :discussions, :everyone_points ]
  before_filter :check_for_user, :only => [:yours, :network, :yours_finished, :yours_created]

  before_filter :setup_filter_dropdown

  caches_action :index, :top, :top_24hr, :top_7days, :top_30days,
                :ads, :controversial, :rising, :newest, :finished, :show,
                :top_points, :discussions, :endorsers, :opposers, :activities,
                :if => proc {|c| c.do_action_cache?},
                :cache_path => proc {|c| c.action_cache_path},
                :expires_in => 5.minutes

  layout :get_layout

  # GET /ideas
  def index
    if params[:term] and request.xhr?
      ideas = Idea.published.find(:all, :select => "ideas.name", :conditions => ["name LIKE ?", "%#{params[:term]}%"], :order => "endorsements_count desc")
      idea_links = []
      ideas.each do |idea|
        idea_links << view_context.link_to(idea.name, idea_path(idea))
      end
    end

    respond_to do |format|
      format.html
      format.js { 
        if not idea_links
          render :nothing => true
        else
          render :json => idea_links
        end
      }
    end
  end
  
  # GET /ideas/yours
  def yours
    @page_title = tr("Your ideas at {instance_name}", "controller/ideas", :instance_name => tr(current_instance.name,"Name from database"))
    @ideas = @user.endorsements.active.by_position.paginate :include => :idea, :page => params[:page], :per_page => params[:per_page]
    @rss_url = yours_ideas_url(:format => 'rss')
    respond_to do |format|
      format.html
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'ideas/list_widget_small')) + "');" }
      format.xml { render :xml => @ideas.to_xml(:include => [:idea], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:include => [:idea], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end
  
  # GET /ideas/yours_top
  def yours_top
    @page_title = tr("Your ideas ranked highest by {instance_name} members", "controller/ideas", :instance_name => tr(current_instance.name,"Name from database"))
    @ideas = current_user.endorsements.active.by_idea_position.paginate :include => :idea, :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html { render :action => "yours" }
      format.xml { render :xml => @endorsements.to_xml(:include => [:idea], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @endorsements.to_json(:include => [:idea], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end  
  
  # GET /ideas/yours_lowest
  def yours_lowest
    @page_title = tr("Your ideas ranked lowest by {instance_name} members", "controller/ideas", :instance_name => tr(current_instance.name,"Name from database"))
    @ideas = current_user.endorsements.active.by_idea_lowest_position.paginate :include => :idea, :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html { render :action => "yours" }
      format.xml { render :xml => @endorsements.to_xml(:include => [:idea], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @endorsements.to_json(:include => [:idea], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end  
  
  # GET /ideas/yours_created
  def yours_created
    @page_title = tr("Ideas you created at {instance_name}", "controller/ideas", :instance_name => tr(current_instance.name,"Name from database"))
    @ideas = @user.created_ideas.published.top_rank.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'ideas/list_widget_small')) + "');" }
      format.xml { render :xml => @ideas.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end  

  # GET /ideas/network
  def network
    @page_title = tr("Your network's ideas", "controller/ideas", :instance_name => tr(current_instance.name,"Name from database"))
    @rss_url = network_ideas_url(:format => 'rss')
    if @user.followings_count > 0
      @ideas = Endorsement.active.find(:all,
        :select => "endorsements.idea_id, sum((#{Endorsement.max_position+1}-endorsements.position)*endorsements.value) as score, count(*) as endorsements_number, ideas.*",
        :joins => "endorsements INNER JOIN ideas ON ideas.id = endorsements.idea_id",
        :conditions => ["endorsements.user_id in (?) and endorsements.position <= #{Endorsement.max_position}",@user.followings.up.collect{|f|f.other_user_id}], 
        :group => "endorsements.idea_id",
        :order => "score desc").paginate :page => params[:page], :per_page => params[:per_page]
        @endorsements = @user.endorsements.active.find(:all, :conditions => ["idea_id in (?)", @ideas.collect {|c| c.idea_id}])
    end
    respond_to do |format|
      format.html
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'ideas/list_widget_small')) + "');" }
      format.xml { render :xml => @ideas.to_xml(:include => [:idea], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:include => [:idea], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end
  
  # GET /ideas/yours_finished
  def yours_finished
    @page_title = tr("Your ideas in progress at {instance_name}", "controller/ideas", :instance_name => tr(current_instance.name,"Name from database"))
    @ideas = @user.endorsements.finished.find(:all, :order => "ideas.status_changed_at desc", :include => :idea).paginate :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html { render :action => "yours" }
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'ideas/list_widget_small')) + "');" }
      format.xml { render :xml => @ideas.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
    if logged_in? and request.format == 'html' and current_user.unread_notifications_count > 0
      for n in current_user.received_notifications.all
        n.read! if n.class == NotificationIdeaFinished and n.unread?
      end    
    end
  end  

  # GET /ideas/ads
  def ads
    @page_title = tr("Ads running at {instance_name}", "controller/ideas", :instance_name => tr(current_instance.name,"Name from database"))
    @ads = Ad.active_first.paginate :include => [:user, :idea], :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html
      format.xml { render :xml => @ads.to_xml(:include => [:idea], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ads.to_json(:include => [:idea], :except => NB_CONFIG['api_exclude_fields']) }
    end
  end

  # GET /ideas/yours_ads
  def yours_ads
    @page_title = tr("Your ads", "controller/ideas", :instance_name => tr(current_instance.name,"Name from database"))
    @ads = current_user.ads.active_first.paginate :include => [:user, :idea], :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html
      format.xml { render :xml => @ads.to_xml(:include => [:idea], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ads.to_json(:include => [:idea], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end  

  # GET /ideas/consider
  def consider
    @page_title = tr("Ideas you should consider", "controller/ideas", :instance_name => tr(current_instance.name,"Name from database"))
    @ideas = current_user.recommend(25)
    if @ideas.empty?
      flash[:error] = tr("You need to endorse a few things before we can recommend other ideas for you to consider. Here are a few random ideas to get started.", "controller/ideas")
      redirect_to :action => "random"
      return
    end
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.rss { render :action => "list" }
      format.xml { render :xml => @ideas.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end    
  end

  # GET /ideas/official
  def official
    @page_title = tr("{official_user_name} ideas", "controller/ideas", :instance_name => tr(current_instance.name,"Name from database"), :official_user_name => current_instance.official_user.name.possessive)
    @rss_url = official_ideas_url(:format => 'rss')
    @ideas = Idea.published.official_endorsed.top_rank.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'ideas/list_widget_small')) + "');" }
      format.xml { render :xml => @ideas.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end

  # GET /ideas/top
  def top
    @page_title = tr("Top ideas", "controller/ideas")
    @rss_url = top_ideas_url(:format => 'rss')
    @ideas = Idea.published.top_rank.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'ideas/list_widget_small')) + "');" }
      format.xml { render :xml => @ideas.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end

  # GET /ideas/top_24hr
  def top_24hr
    @page_title = tr("Top ideas past 24 hours", "controller/ideas")
    @rss_url = top_ideas_url(:format => 'rss')
    @ideas = Idea.published.top_24hr.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'ideas/list_widget_small')) + "');" }
      format.xml { render :xml => @ideas.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end

  # GET /ideas/top_7days
  def top_7days
    @page_title = tr("Top ideas past 7 days", "controller/ideas")
    @rss_url = top_ideas_url(:format => 'rss')
    @ideas = Idea.published.top_7days.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'ideas/list_widget_small')) + "');" }
      format.xml { render :xml => @ideas.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end

  # GET /ideas/top_30days
  def top_30days
    @page_title = tr("Top ideas past 30 days", "controller/ideas")
    @rss_url = top_ideas_url(:format => 'rss')
    @ideas = Idea.published.top_30days.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'ideas/list_widget_small')) + "');" }
      format.xml { render :xml => @ideas.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end

  # GET /ideas/rising
  def rising
    @page_title = tr("Ideas rising in the rankings", "controller/ideas")
    @rss_url = rising_ideas_url(:format => 'rss')
    @ideas = Idea.published.rising.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'ideas/list_widget_small')) + "');" }
      format.xml { render :xml => @ideas.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end
  
  # GET /ideas/falling
  def falling
    @page_title = tr("Ideas falling in the rankings", "controller/ideas")
    @rss_url = falling_ideas_url(:format => 'rss')
    @ideas = Idea.published.falling.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'ideas/list_widget_small')) + "');" }
      format.xml { render :xml => @ideas.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end  
  
  # GET /ideas/controversial
  def controversial
    @page_title = tr("Most controversial ideas", "controller/ideas")
    @rss_url = controversial_ideas_url(:format => 'rss')
    @ideas = Idea.published.controversial.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'ideas/list_widget_small')) + "');" }
      format.xml { render :xml => @ideas.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end
  
  # GET /ideas/finished
  def finished
    @page_title = tr("Ideas in progress", "controller/ideas")
    @rss_url = finished_ideas_url(:format => 'rss')
    @ideas = Idea.finished.not_removed.by_most_recent_status_change.paginate :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html { render :action => "list" }
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'ideas/list_widget_small')) + "');" }
      format.xml { render :xml => @ideas.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end    
  end  
  
  # GET /ideas/random
  def random
    @page_title = tr("Random ideas", "controller/ideas")
    if User.adapter == 'postgresql'
      @ideas = Idea.published.paginate :order => "RANDOM()", :page => params[:page], :per_page => params[:per_page]
    else
      @ideas = Idea.published.paginate :order => "rand()", :page => params[:page], :per_page => params[:per_page]
    end
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'ideas/list_widget_small')) + "');" }
      format.xml { render :xml => @ideas.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end

  # GET /ideas/newest
  def newest
    @page_title = tr("Newest ideas", "controller/ideas")
    @rss_url = newest_ideas_url(:format => 'rss')
    @ideas = Idea.published.newest.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html
      format.rss { render :action => "list" }
      format.js { render :layout => false, :text => "document.write('" + js_help.escape_javascript(render_to_string(:layout => false, :template => 'ideas/list_widget_small')) + "');" }
      format.xml { render :xml => @ideas.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end    
  end
  
  # GET /ideas/untagged
  def untagged
    @page_title = tr("Untagged (or uncategorized) ideas", "controller/ideas")
    @rss_url = untagged_ideas_url(:format => 'rss')
    @ideas = Idea.published.untagged.paginate :page => params[:page], :per_page => params[:per_page]
    get_endorsements
    respond_to do |format|
      format.html { render :action => "list" }
      format.rss { render :action => "list" }
      format.xml { render :xml => @ideas.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end  
  end  
  
  # GET /ideas/1
  def show
    @page_title = @idea.name
    @show_only_last_process = false
    @point_value = 0
    @points_top_up = @idea.points.published.by_helpfulness.up_value.five
    @points_top_down = @idea.points.published.by_helpfulness.down_value.five
    @points_new_up = @idea.points.published.by_recently_created.up_value.five.reject {|p| @points_top_up.include?(p)}
    @points_new_down = @idea.points.published.by_recently_created.down_value.five.reject {|p| @points_top_down.include?(p)}
    @total_up_points = @idea.points.published.up_value.count
    @total_down_points = @idea.points.published.down_value.count
    @total_up_points_new = [0,@total_up_points-@points_top_up.length].max
    @total_down_points_new = [0,@total_down_points-@points_top_down.length].max
    get_qualities([@points_new_up,@points_new_down,@points_top_up,@points_top_down])

    @activities = @idea.activities.active.top_discussions.for_all_users :include => :user
    if logged_in? and @endorsement
      if @endorsement.is_up?
        @relationships = @idea.relationships.endorsers_endorsed.by_highest_percentage.find(:all, :include => :other_idea).group_by {|o|o.other_idea}
      elsif @endorsement.is_down?
        @relationships = @idea.relationships.opposers_endorsed.by_highest_percentage.find(:all, :include => :other_idea).group_by {|o|o.other_idea}
      end
    else
      @relationships = @idea.relationships.who_endorsed.by_highest_percentage.find(:all, :include => :other_idea).group_by {|o|o.other_idea}
    end
    @endorsements = nil
    if logged_in? # pull all their endorsements on the ideas shown
      @endorsements = Endorsement.find(:all, :conditions => ["idea_id in (?) and user_id = ? and status='active'", @relationships.collect {|other_idea, relationship| other_idea.id},current_user.id])
    end    
    respond_to do |format|
      format.html { render :action => "show" }
      format.xml { render :xml => @idea.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @idea.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end

  def show_feed
    last = params[:last].blank? ? Time.now + 1.second : Time.parse(params[:last])
    @activities = @idea.activities.active.top_discussions.feed(last).for_all_users :include => :user
    respond_to do |format|
      format.js
    end
  end

  def opposer_points
    @page_title = tr("Points opposing {idea_name}", "controller/ideas", :idea_name => @idea.name)
    @point_value = -1  
    @points = @idea.points.published.by_opposer_helpfulness.paginate :page => params[:page], :per_page => params[:per_page]
    get_qualities
    respond_to do |format|
      format.html { render :action => "points" }
      format.xml { render :xml => @points.to_xml(:include => [:idea, :other_idea], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @points.to_json(:include => [:idea, :other_idea], :except => NB_CONFIG['api_exclude_fields']) }
    end
  end
  
  def endorser_points
    @page_title = tr("Points supporting {idea_name}", "controller/ideas", :idea_name => @idea.name)
    @point_value = 1
    @points = @idea.points.published.by_endorser_helpfulness.paginate :page => params[:page], :per_page => params[:per_page]
    get_qualities
    respond_to do |format|
      format.html { render :action => "points" }
      format.xml { render :xml => @points.to_xml(:include => [:idea, :other_idea], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @points.to_json(:include => [:idea, :other_idea], :except => NB_CONFIG['api_exclude_fields']) }
    end
  end
  
  def neutral_points
    @page_title = tr("Points about {idea_name}", "controller/ideas", :idea_name => @idea.name)
    @point_value = 2 
    @points = @idea.points.published.by_neutral_helpfulness.paginate :page => params[:page], :per_page => params[:per_page]
    get_qualities
    respond_to do |format|
      format.html { render :action => "points" }
      format.xml { render :xml => @points.to_xml(:include => [:idea, :other_idea], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @points.to_json(:include => [:idea, :other_idea], :except => NB_CONFIG['api_exclude_fields']) }
    end
  end  
  
  def everyone_points
    @page_title = tr("Best points on {idea_name}", "controller/ideas", :idea_name => @idea.name)
    @point_value = 0 
    @points = @idea.points.published.by_helpfulness.paginate :page => params[:page], :per_page => params[:per_page]
    get_qualities
    respond_to do |format|
      format.html { render :action => "points" }
      format.xml { render :xml => @points.to_xml(:include => [:idea, :other_idea], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @points.to_json(:include => [:idea, :other_idea], :except => NB_CONFIG['api_exclude_fields']) }
    end
  end  

  def opposed_top_points
    @page_title = tr("Points opposing {idea_name}", "controller/ideas", :idea_name => @idea.name)
    @point_value = -1
    if params[:by_newest]
      @points = @idea.points.published.down_value.by_recently_created.paginate :page => params[:page], :per_page => params[:per_page]
    else
      @points = @idea.points.published.down_value.by_helpfulness.paginate :page => params[:page], :per_page => params[:per_page]
    end
    get_qualities
    respond_to do |format|
      format.html { render :action => "points" }
      format.xml { render :xml => @points.to_xml(:include => [:idea, :other_idea], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @points.to_json(:include => [:idea, :other_idea], :except => NB_CONFIG['api_exclude_fields']) }
    end
  end
  
  def endorsed_top_points
    @page_title = tr("Points supporting {idea_name}", "controller/ideas", :idea_name => @idea.name)
    @point_value = 1
    if params[:by_newest]
      @points = @idea.points.published.up_value.by_recently_created.paginate :page => params[:page], :per_page => params[:per_page]
    else
      @points = @idea.points.published.up_value.by_helpfulness.paginate :page => params[:page], :per_page => params[:per_page]
    end
    get_qualities
    respond_to do |format|
      format.html { render :action => "points" }
      format.xml { render :xml => @points.to_xml(:include => [:idea, :other_idea], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @points.to_json(:include => [:idea, :other_idea], :except => NB_CONFIG['api_exclude_fields']) }
    end
  end

  def idea_detail
    setup_top_points(1)
    render :partial=>"ideas/idea_detail", :layout=>false
  end

  def top_points
    @page_title = tr("Top points", "controller/ideas", :idea_name => @idea.name)
    setup_top_points(5)
    respond_to do |format|
      format.html { render :action => "top_points" }
      format.xml { render :xml => @points.to_xml(:include => [:idea, :other_idea], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @points.to_json(:include => [:idea, :other_idea], :except => NB_CONFIG['api_exclude_fields']) }
    end
  end  
  
  def points
    redirect_to :action => "everyone_points"
  end
  
  def discussions
    @page_title = tr("Discussions on {idea_name}", "controller/ideas", :idea_name => @idea.name)
    @activities = @idea.activities.active.discussions.by_recently_updated.for_all_users.paginate :page => params[:page], :per_page => 10
    if @activities.empty? # pull all activities if there are no discussions
      @activities = @idea.activities.active.paginate :page => params[:page]
    end
    respond_to do |format|
      format.html { render :action => "activities" }
      format.xml { render :xml => @activities.to_xml(:include => :comments, :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @activities.to_json(:include => :comments, :except => NB_CONFIG['api_exclude_fields']) }
    end
  end  
  
  def comments
    @idea = Idea.find(params[:id])
    @page_title = tr("Latest comments on {idea_name}", "controller/ideas", :idea_name => @idea.name)
    @comments = Comment.published.by_recently_created.find(:all, :conditions => ["activities.idea_id = ?",@idea.id], :include => :activity).paginate :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html
      format.rss { render :template => "rss/comments" }
      format.xml { render :xml => @comments.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @comments.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end    
  end
  
  # GET /ideas/1/activities
  def activities
    @page_title = tr("Activity on {idea_name}", "controller/ideas", :idea_name => @idea.name)
    @activities = @idea.activities.active.for_all_users.by_recently_created.paginate :include => :user, :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html
      format.rss { render :template => "rss/activities" }
      format.xml { render :xml => @activities.to_xml(:include => :comments, :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @activities.to_json(:include => :comments, :except => NB_CONFIG['api_exclude_fields']) }
    end
  end 
  
  # GET /ideas/1/endorsers
  def endorsers
    @page_title = tr("{number} people endorse {idea_name}", "controller/ideas", :idea_name => @idea.name, :number => @idea.up_endorsements_count)
    if request.format != 'html'
      @endorsements = @idea.endorsements.active_and_inactive.endorsing.paginate :page => params[:page], :per_page => params[:per_page], :include => :user
    end
    respond_to do |format|
      format.html
      format.xml { render :xml => @endorsements.to_xml(:include => :user, :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @endorsements.to_json(:include => :user, :except => NB_CONFIG['api_exclude_fields']) }      
    end
  end

  # GET /ideas/1/opposers
  def opposers
    @page_title = tr("{number} people opposed {idea_name}", "controller/ideas", :idea_name => @idea.name, :number => @idea.down_endorsements_count)
    if request.format != 'html'
      @endorsements = @idea.endorsements.active_and_inactive.opposing.paginate :page => params[:page], :per_page => params[:per_page], :include => :user
    end
    respond_to do |format|
      format.html
      format.xml { render :xml => @endorsements.to_xml(:include => :user, :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @endorsements.to_json(:include => :user, :except => NB_CONFIG['api_exclude_fields']) }      
    end
  end

  # GET /ideas/new
  # GET /ideas/new.xml
  def new
    @idea = Idea.new unless @idea
    @idea.points.build

    if @ideas
      @endorsements = Endorsement.find(:all, :conditions => ["idea_id in (?) and user_id = ? and status='active'", @ideas.collect {|c| c.id},current_user.id])
    end    

    respond_to do |format|
      format.html # new.html.erb
    end
  end

  # GET /ideas/1/edit
  def edit
    @idea = Idea.find(params[:id])
    @page_name = tr("Edit {idea_name}", "controller/ideas", :idea_name => @idea.name)
    if not (current_user.id == @idea.user_id and @idea.endorsements_count < 2) and not current_user.is_admin?
      flash[:error] = tr("You cannot change a idea's name once other people have endorsed it.", "controller/ideas")
      redirect_to @idea and return
    end
    respond_to do |format|
      format.html # new.html.erb
    end    
  end
  
  # POST /ideas
  # POST /ideas.xml
  def create
    if not logged_in?
      flash[:notice] = tr("First you need to fill out this quick form and agree to the rules, then you can start adding your ideas.", "controller/ideas")
      session[:query] = params[:idea][:name] if params[:idea]
      access_denied
      return
    end
  
    Rails.logger.debug("Point character length: #{params[:idea][:points_attributes]["0"][:content].length} #{params[:idea][:name].length}")

    if current_sub_instance and current_sub_instance.required_tags and not params[:idea][:idea_type]
      # default to the first tag
      params[:idea][:idea_type] = current_sub_instance.required_tags.split(',')[0]
    end

    @idea = Idea.new(params[:idea])
    tags = []
    tags << @idea.category.name if @idea.category
    params.each do |p,v|
      tags << v if p.include?("special_checkbox_tag_")
    end
    params.each do |a,b|
      tags << b if a.include?("sub_tag_")
    end
    tags += params[:custom_tags].split(",").collect {|t| t.strip} if params[:custom_tags] and params[:custom_tags]!=""

    unless tags.empty?
      @idea.issue_list = tags.join(",")
    end
    @idea.user = current_user
    @idea.ip_address = request.remote_ip
    @idea.request = request
    @saved = @idea.save
    
    if @saved
      first_point = @idea.points.first
      first_point.setup_revision
      first_point.reload
      @endorsement = @idea.endorse(current_user,request,current_sub_instance,@referral)
      quality = first_point.point_qualities.find_or_create_by_user_id_and_value(current_user.id, true)
      if current_user.endorsements_count > 24
        session[:endorsement_page] = (@endorsement.position/25).to_i+1
        session[:endorsement_page] -= 1 if @endorsement.position == (session[:endorsement_page]*25)-25
      end    
    else
      # see if it already exists
      query = params[:idea][:name].strip
      same_name_idea = Idea.find(:first, :conditions => ["name = ? and status = 'published'", query], :order => "endorsements_count desc")
      flash[:current_same_name_idea_id] = same_name_idea.id if same_name_idea
    end
    
    respond_to do |format|
      if @saved
        format.html { 
          flash[:notice] = tr("Thanks for adding {idea_name}", "controller/ideas", :idea_name => @idea.name)
          redirect_to(@idea)
        }
        format.js {
          render :update do |page|
            page.redirect_to @idea
          end
        }        
      else
        format.html { render :controller => "ideas", :action => "new", :notice=>flash[:notice] }
      end
    end
  end

  # POST /ideas/1/endorse
  def endorse
    @value = (params[:value]||1).to_i
    @idea = Idea.find(params[:id])
    if not logged_in?
      session[:idea_id] = @idea.id
      session[:value] = @value
      access_denied
      return
    end
    if @value == 1
      @endorsement = @idea.endorse(current_user,request,current_sub_instance,@referral)
    else
      @endorsement = @idea.oppose(current_user,request,current_sub_instance,@referral)
    end
    if params[:ad_id]    
      @ad = Ad.find(params[:ad_id])
      @ad.vote(current_user,@value,request) if @ad
    else
      @ad = Ad.find_by_idea_id_and_status(@idea.id,'active')
      if @ad and @ad.shown_ads.find_by_user_id(current_user.id)
        @ad.vote(current_user,@value,request) 
      end
    end
    if current_user.endorsements_count > 24
      session[:endorsement_page] = (@endorsement.position/25).to_i+1
      session[:endorsement_page] -= 1 if @endorsement.position == (session[:endorsement_page]*25)-25
    end
    @idea.reload
    respond_to do |format|
      format.js {
        render :update do |page|
          if params[:region] == 'idea_left'
            page.replace_html 'idea_' + @idea.id.to_s + "_button",render(:partial => "ideas/debate_buttons", :locals => {:idea => @idea, :endorsement => @endorsement, :region=>"idea_left"})
            page.replace_html 'idea_' + @idea.id.to_s + "_position",render(:partial => "endorsements/position", :locals => {:endorsement => @endorsement})
            page.replace 'endorser_link', render(:partial => "ideas/endorser_link")
            page.replace 'opposer_link', render(:partial => "ideas/opposer_link")
            if @value == 1          
              @activity = ActivityEndorsementNew.find_by_idea_id_and_user_id(@idea.id,current_user.id, :order => "created_at desc")
            else
              @activity = ActivityOppositionNew.find_by_idea_id_and_user_id(@idea.id,current_user.id, :order => "created_at desc")
            end            
            if @activity and not params[:no_activites]
              page.insert_html :top, 'activities', render(:partial => "activities/show", :locals => {:activity => @activity, :suffix => "_noself"})
            end
          elsif params[:region] == 'idea_subs'
            page.replace_html 'idea_' + @idea.id.to_s + "_button",render(:partial => "ideas/button_subs", :locals => {:idea => @idea, :endorsement => @endorsement})
            page.replace 'endorser_link', render(:partial => "ideas/endorser_link")
            page.replace 'opposer_link', render(:partial => "ideas/opposer_link")
          elsif params[:region] == 'idea_inline'
            page<<"$('.idea_#{@idea.id.to_s}_button_small').replaceWith('#{escape_javascript(render(:partial => "ideas/debate_buttons", :locals => {:idea => @idea, :endorsement => @endorsement, :region => params[:region]}))}')"
            page<<"$('.idea_#{@idea.id.to_s}_endorsement_count').replaceWith('#{escape_javascript(render(:partial => "ideas/endorsement_count", :locals => {:idea => @idea}))}')"
          elsif params[:region] == 'ad_top' and @ad
            page.replace 'encouragements', render(:partial => "ads/pick")
            #page << 'if (jQuery("#notification_show").length > 0) { jQuery("#notification_show").corners(); }'
          else
            page << "alert('error');"
          end
          page.replace_html 'your_ideas_container', :partial => "ideas/yours"
        end
      }
    end
  end

  # PUT /ideas/1
  # PUT /ideas/1.xml
  def update
    @idea = Idea.find(params[:id])
    @previous_name = @idea.name
    @page_name = tr("Edit {idea_name}", "controller/ideas", :idea_name => @idea.name)

    if params[:idea]
      if params[:idea][:idea_type] and current_sub_instance and current_sub_instance.required_tags
        required_tags = current_sub_instance.required_tags.split(',')
        issues = @idea.issue_list
        if not issues.include?(params[:idea][:idea_type])
          new_issues = issues - required_tags
          new_issues << params[:idea][:idea_type]
          @idea.issue_list = new_issues.join(',')
        end
      end
      if params[:idea]["finished_status_date(1i)"]
        # TODO: isn't there an easier way to do this?
        params[:idea][:finished_status_date] = Date.new(params[:idea].delete("finished_status_date(1i)").to_i, params[:idea].delete("finished_status_date(2i)").to_i, params[:idea].delete("finished_status_date(3i)").to_i)
      end
      if params[:idea][:category]
        old_category = @idea.category
        new_category = Category.find(params[:idea][:category])
        params[:idea][:category] = new_category
        current_issues = @idea.issue_list
        remove_issues = [old_category.name]
        add_issues = [new_category.name]
        new_issues = add_issues | (current_issues - remove_issues)
        params[:idea][:issue_list] = new_issues.join(',')
      end
      if params[:idea][:finished_status_message]
        change_log = @idea_status_changelog = IdeaStatusChangeLog.new(
            idea_id: @idea.id,
            date: params[:idea][:finished_status_date],
            content: params[:idea][:finished_status_message],
            subject: params[:idea][:finished_status_subject]
        )
        @idea_status_changelog.save
      end
      if params[:idea][:official_status] and params[:idea][:official_status].to_i != @idea.official_status
        @change_status = params[:idea][:official_status].to_i
        #params[:idea].delete(:official_status)
      end
    end
    respond_to do |format|
      if params[:idea][:name] and @idea.update_attributes(params[:idea]) and @previous_name != params[:idea][:name]
        # already renamed?
        @activity = ActivityIdeaRenamed.find_by_user_id_and_idea_id(current_user.id,@idea.id)
        if @activity
          @activity.update_attribute(:changed_at,Time.now)
        else
          @activity = ActivityIdeaRenamed.create(:user => current_user, :idea => @idea)
        end
        format.html {
          flash[:notice] = tr("Saved {idea_name}", "controller/ideas", :idea_name => @idea.name)
          redirect_to(@idea)
        }
        format.js {
          render :update do |page|
            page.select('#idea_' + @idea.id.to_s + '_edit_form').each {|item| item.remove}
            page.select('#activity_and_comments_' + @activity.id.to_s).each {|item| item.remove}
            page.insert_html :top, 'activities', render(:partial => "activities/show", :locals => {:activity => @activity, :suffix => "_noself"})
            page.replace_html 'idea_' + @idea.id.to_s + '_name', render(:partial => "ideas/name", :locals => {:idea => @idea})
            # page.visual_effect :highlight, 'idea_' + @idea.id.to_s + '_name'
          end
        }
      else
        format.html {
          if params[:idea][:finished_status_message]
            flash[:notice] = tr('Status updated with "{status_text}"', "controller/ideas", status_text: params[:idea][:finished_status_subject])
          end
          redirect_to(@idea)
        }
        format.js {
          render :update do |page|
            page.select('#idea_' + @idea.id.to_s + '_edit_form').each {|item| item.remove}
            page.insert_html :top, 'activities', render(:partial => "ideas/new_inline", :locals => {:idea => @idea})
            page['idea_name'].focus
          end
        }
      end
      @idea.reload

      if @change_status
        @idea.change_status!(@change_status)
        @idea.delay.deactivate_endorsements
      end
      if change_log
        @idea.create_status_update(change_log)
        User.delay.send_status_email(@idea.id, params[:idea][:official_status], params[:idea][:finished_status_date], params[:idea][:finished_status_subject], params[:idea][:finished_status_message])
      end
    end
  end

  # PUT /ideas/1/create_short_url
  def create_short_url
    @idea = Idea.find(params[:id])
    @short_url = @idea.create_short_url
    if @short_url
      @idea.save(:validate => false)
    end
    respond_to do |format|
      format.js {
        render :update do |page|
          page.replace "idea_short_url", render(:partial => "ideas/short_url", :locals => {:idea => @idea})
          page << "short_url.select();"
        end
      }
    end
  end

  # PUT /ideas/1/flag_inappropriate
  def flag
    @idea = Idea.find(params[:id])
    @idea.flag_by_user(current_user)

    respond_to do |format|
      format.html { redirect_to(comments_url) }
      format.js {
        render :update do |page|
          if current_user.is_admin?
            page.replace_html "idea_report_#{@idea.id}", render(:partial => "ideas/report_content", :locals => {:idea => @idea})
          else
            page.replace_html "idea_report_#{@idea.id}","<div class='warning_inline'> #{tr("Thanks for bringing this to our attention", "controller/ideas")}</div>"
          end
        end        
      }
    end    
  end  

  def abusive
    @idea = Idea.find(params[:id])
    @idea.do_abusive
    @idea.remove!
    respond_to do |format|
      format.js {
        render :update do |page|
          page.replace_html "idea_flag_#{@idea.id}", "<div class='warning_inline'>#{tr("The content has been deleted and a warning_sent", "controller/ideas")}</div>"
        end        
      }
    end    
  end

  def not_abusive
    @idea = Idea.find(params[:id])
    @idea.update_attribute(:flags_count, 0)
    respond_to do |format|
      format.js {
        render :update do |page|
          page.replace_html "idea_flag_#{@idea.id}",""
        end        
      }
    end    
  end
  
  # PUT /ideas/1/bury
  def bury
    @idea = Idea.find(params[:id])
    @idea.bury!
    ActivityIdeaBury.create(:idea => @idea, :user => current_user, :sub_instance => current_sub_instance)
    respond_to do |format|
      flash[:notice] = tr("{idea_name} is now buried, it will no longer be displayed in the charts.", "controller/ideas", :idea_name => @idea.name)
      format.html { redirect_to(@idea) }
    end
  end  
  
  # PUT /ideas/1/successful
  def successful
    @idea = Idea.find(params[:id])
    @idea.successful!
    respond_to do |format|
      flash[:notice] = tr("{idea_name} is now marked finished and successful", "controller/ideas", :idea_name => @idea.name)
      format.html { redirect_to(@idea) }
    end
  end  
  
  # PUT /ideas/1/intheworks
  def intheworks
    @idea = Idea.find(params[:id])
    @idea.intheworks!
    respond_to do |format|
      flash[:notice] = tr("{idea_name} is now marked 'in the works'", "controller/ideas", :idea_name => @idea.name)
      format.html { redirect_to(@idea) }
    end
  end  
  
  # PUT /ideas/1/failed
  def failed
    @idea = Idea.find(params[:id])
    @idea.failed!
    respond_to do |format|
      flash[:notice] = tr("{idea_name} is now marked finished and failed", "controller/ideas", :idea_name => @idea.name)
      format.html { redirect_to(@idea) }
    end
  end  
  
  # PUT /ideas/1/compromised
  def compromised
    @idea = Idea.find(params[:id])
    @idea.compromised!
    respond_to do |format|
      flash[:notice] = tr("{idea_name} is now marked finished but compromised", "controller/ideas", :idea_name => @idea.name)
      format.html { redirect_to(@idea) }
    end
  end  
  
  def endorsed
    @idea = Idea.find(params[:id])
    @endorsement = @idea.endorse(current_user,request,current_sub_instance,@referral)
    redirect_to @idea
  end

  def opposed
    @idea = Idea.find(params[:id])
    @endorsement = @idea.oppose(current_user,request,current_sub_instance,@referral)
    redirect_to @idea
  end

  # GET /ideas/1/tag
  def tag
    @idea = Idea.find(params[:id])
    respond_to do |format|
      format.js {
        render :update do |page|
          page.replace_html 'idea_' + @idea.id.to_s + '_tags', render(:partial => "ideas/tag", :locals => {:idea => @idea})
          page['idea_' + @idea.id.to_s + "_issue_list"].focus
        end        
      }
    end
  end

  # POST /ideas/1/tag
  def tag_save
    @idea = Idea.find(params[:id])
    @idea.update_attributes(params[:idea])
    respond_to do |format|
      format.js {
        render :update do |page|
          page.replace_html 'idea_' + @idea.id.to_s + '_tags', render(:partial => "ideas/tag_show", :locals => {:idea => @idea})
        end        
      }
    end
  end
  
  # DELETE /ideas/1
  def destroy
    if current_user.is_admin?
      @idea = Idea.find(params[:id])
    else
      @idea = current_user.created_ideas.find(params[:id])
    end
    return unless @idea
    name = @idea.name
    @idea.remove!
    flash[:notice] = tr("Permanently deleting {idea_name}. This may take a few minutes depending on how many endorsements/oppositions need to be removed.", "controller/ideas", :idea_name => name)
    respond_to do |format|
      format.html { redirect_to yours_created_ideas_url }
    end
  end

  def update_status
    @idea = Idea.find(params[:id])
    @page_name = tr("Edit the status of {idea_name}", "controller/ideas", :idea_name => @idea.name)
    if not current_user.is_admin?
      flash[:error] = tr("You cannot change a idea's name once other people have endorsed it.", "controller/ideas")
      redirect_to @idea and return
    end
    respond_to do |format|
      format.html
    end
  end

  def statistics
    @idea = Idea.find(params[:id])
    respond_to do |format|
      format.html
      format.js { render_to_facebox }
    end
  end

  private
  
    def get_endorsements
      @endorsements = nil
      if logged_in? # pull all their endorsements on the ideas shown
        @endorsements = current_user.endorsements.active.find(:all, :conditions => ["idea_id in (?)", @ideas.collect {|c| c.id}])
      end
    end
    
    def load_endorsement
      @idea = Idea.find(params[:id])
      if @idea.status == 'removed' or @idea.status == 'abusive'
        flash[:notice] = tr("That idea was deleted", "controller/ideas")
        redirect_to "/"
        return false
      end

      @endorsement = nil
      if logged_in? # pull all their endorsements on the ideas shown
        @endorsement = @idea.endorsements.active.find_by_user_id(current_user.id)
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
        if logged_in? # pull all their qualities on the ideas shown
          @qualities = PointQuality.find(:all, :conditions => ["point_id in (?) and user_id = ? ", @points.collect {|c| c.id},current_user.id])
        end      
      end      
    end

    def setup_top_points(limit)
      @point_value = 0
      @points_top_up = @idea.points.published.by_helpfulness.up_value.limit(limit)
      @points_top_down = @idea.points.published.by_helpfulness.down_value.limit(limit)
      @points_new_up = @idea.points.published.by_recently_created.up_value.limit(limit).reject {|p| @points_top_up.include?(p)}
      @points_new_down = @idea.points.published.by_recently_created.down_value.limit(limit).reject {|p| @points_top_down.include?(p)}
      @total_up_points = @idea.points.published.up_value.count
      @total_down_points = @idea.points.published.down_value.count
      @total_up_points_new = [0,@total_up_points-@points_top_up.length].max
      @total_down_points_new = [0,@total_down_points-@points_top_down.length].max
      get_qualities([@points_new_up,@points_new_down,@points_top_up,@points_top_down])
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
      @items[1]=[tr("Top All", "view/ideas"), top_ideas_url]
      @items[2]=[tr("Top Active 24 hours", "view/ideas"), top_24hr_ideas_url]
      @items[3]=[tr("Top Active 7 days", "view/ideas"), top_7days_ideas_url]
      @items[4]=[tr("Top Active 30 days", "view/ideas"), top_30days_ideas_url]
      @items[6]=[tr("New", "view/ideas"), newest_ideas_url]
      @items[8]=[tr("Random", "view/ideas"), random_ideas_url]
      @items[9]=[tr("In Progress", "view/ideas"), finished_ideas_url]
      @items[10]=[tr("Controversial", "view/ideas"), controversial_ideas_url]
      @items[11]=[tr("Ads", "view/ideas"), ads_ideas_url]
      @items[12]=[tr("Rising", "view/ideas"), rising_ideas_url]
      @items[13]=[tr("Falling", "view/ideas"), rising_ideas_url]
      if logged_in?
        @items[14]=[tr("Your network", "view/ideas"), network_ideas_url]
        @items[15]=[tr("Yours", "view/ideas"), yours_ideas_url]
      end
      @items
    end
end
