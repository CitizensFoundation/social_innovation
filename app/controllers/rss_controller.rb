class RssController < ApplicationController
  
  skip_before_filter :check_blast_click
  skip_before_filter :check_subdomain
  skip_before_filter :check_idea
  skip_before_filter :check_referral    
  skip_before_filter :update_loggedin_at
  skip_before_filter :check_facebook
  
  before_filter :login_from_rss_code

  def your_notifications
    @page_title = tr("{user_name} notifications at {instance_name}", "controller/rss", :user_name => @user.login.possessive, :instance_name => tr(current_instance.name,"Name from database"))
    @notifications = @user.received_notifications.active.by_recently_created.find(:all, :include => [:notifiable]).paginate :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.rss { render :template => "rss/notifications" }
    end
  end
  
  def your_comments
    @page_title = tr("Latest comments on {user_name} discussions", "controller/rss", :user_name => @user.login.possessive, :instance_name => tr(current_instance.name,"Name from database"))
    @notifications = @user.received_notifications.active.comments.by_recently_created.find(:all, :include => [:notifiable]).paginate :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.rss { render :template => "rss/notifications" }
    end
  end  
  
  def your_ideas_created_activities
    @page_title = tr("Everything happening on ideas you created", "controller/rss", :instance_name => tr(current_instance.name,"Name from database"))
    @activities = nil
    created_idea_ids = @user.created_ideas.collect{|p|p.id}
    if created_idea_ids.any?
      @activities = Activity.active.filtered.by_recently_created.paginate :conditions => ["idea_id in (?)",created_idea_ids], :page => params[:page], :per_page => params[:per_page]
    end
    respond_to do |format|
      format.rss { render :template => "rss/activities" }
    end
  end
  
  private

  def login_from_rss_code
    return false unless request.format == 'rss' and params[:c] and params[:c].length == 40
    @user =  User.find_by_rss_code(params[:c])
  end
  
end
