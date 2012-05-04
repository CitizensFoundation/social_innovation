class UsersController < ApplicationController

  before_filter :login_required, :only => [:destroy, :request_validate_user_for_country, :validate_user_for_country, :resend_activation, :follow, :unfollow, :endorse, :subscriptions, :disable_facebook]
  before_filter :current_user_required, :only => [:resend_activation]
  before_filter :admin_required, :only => [:list_suspended, :suspend, :unsuspend, :impersonate, :edit, :update, :signups, :make_admin, :reset_password]
  
  caches_action :show,
                :if => proc {|c| c.do_action_cache? },
                :cache_path => proc {|c| c.action_cache_path},
                :expires_in => 5.minutes

  def index
    if params[:term]
      @users = User.active.find(:all, :conditions => ["login LIKE ?", "#{h(params[:term])}%"], :order => "users.login asc")
    else
      @users = User.active.by_ranking.paginate :page => params[:page], :per_page => params[:per_page]  
    end
    respond_to do |format|
      format.html { redirect_to :controller => "network" }
      format.js { render :text => @users.collect{|p|p.login}.join("\n") }
      format.xml { render :xml => @users.to_xml(:include => [:top_endorsement, :referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @users.to_json(:include => [:top_endorsement, :referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end
  
  def request_validate_user_for_country
    unless @iso_country
      flash[:error] = tr("Your country was not detected.", "controller/users", :user_name => @user.name)
      redirect_to '/'
    end
  end

  def validate_user_for_country
    email = params[:user][:email]
    user = User.find_by_email(email)
    if user and @iso_country
      user.add_iso_country_access!(@iso_country.code)
      flash[:error] = tr("{email} has allowed access to #{@iso_country.country_english_name}.", "controller/users", :user_name => @user.name)
      redirect_to '/'
    else
      flash[:error] = tr("{email} is not found.", "controller/users", :user_name => @user.name)
      redirect_to '/'
    end
  end
  
  def suspended
  end

  def list_suspended
    @users = User.suspended.paginate :page => params[:page], :per_page => params[:per_page] 
  end

  def disable_facebook
#    @user = current_user
#    @user.facebook_uid=nil
#    @user.save(:validate => false)
#    fb_cookie_destroy
    redirect_to '/'
  end
  
  def set_email
    @user = current_user
    flash[:notice]=nil
    if request.put?
      @user.email = params[:user][:email]
      @user.have_sent_welcome = true
      if @user.save
        @user.send_welcome
        redirect_back_or_default('/')
      else
        flash[:notice]=tr("Email not accepted", "controller/users")
        redirect_to "/set_email"
      end
    end
  end
  
  def subscriptions
    @subscription_user = current_user
    if request.put?
      TagSubscription.delete_all(["user_id = ?",current_user.id])
      Tag.all.each do |tag|
        tag_checkbox_id = "subscribe_to_tag_id_#{tag.id}"
        if params[:user][tag_checkbox_id]
          subscription = TagSubscription.new
          subscription.user_id = current_user.id
          subscription.tag_id = tag.id
          subscription.save
        end
      end
      Rails.logger.info("Starting HASH #{params[:user].inspect}")
      params[:user].each do |hash_value,x|
        Rails.logger.info(hash_value)
        if hash_value.include?("to_tag_id")
          Rails.logger.info("DELETING: #{hash_value}")
          params[:user].delete(hash_value)
        end
      end
      Rails.logger.info("After HASH #{params[:user].inspect}")
      if not current_user.reports_enabled and params[:user][:reports_enabled].to_i==1
        params[:user][:last_sent_report]=Time.now
      end
      current_user.update_attributes(params[:user])
      current_user.save(:validate => false)
      redirect_to "/"
    end
  end
  
  # render new.rhtml
  def new
    if logged_in?
      redirect_to "/"
      return
    end
    store_previous_location
    respond_to do |format|
      format.html
    end
  end
  
  def edit
    @user = User.find(params[:id])
    redirect_to '/' and return if check_for_suspension
    @page_title = tr("Changing settings for {user_name}", "controller/users", :user_name => @user.name)
  end
  
  def update
    @user = User.find(params[:id])
    @page_title = tr("Changing settings for {user_name}", "controller/users", :user_name => @user.name)
    respond_to do |format|
      if @user.update_attributes(params[:user])
        flash[:notice] = tr("Saved settings for {user_name}", "controller/users", :user_name => @user.name)
        @page_title = tr("Changing settings for {user_name}", "controller/users", :user_name => @user.name)
        format.html { redirect_to @user }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @page.errors, :status => :unprocessable_entity }
      end
    end
  end  
  
  def signups
    @user = User.find(params[:id])
    redirect_to '/' and return if check_for_suspension
    @page_title = tr("Email notifications for {user_name}", "controller/users", :user_name => @user.name)
    @rss_url = url_for(:only_path => false, :controller => "rss", :action => "your_notifications", :format => "rss", :c => @user.rss_code)
    @sub_instances = SubInstance.find(:all, :conditions => "is_optin = true and status = 'active' and id <> 3")
  end
    
  # GET /users/1
  # GET /users/1.xml
  def show
    @user = User.find(params[:id])
    redirect_to '/' and return if check_for_suspension
    @page_title = tr("{user_name} at {instance_name}", "controller/users", :user_name => @user.name, :instance_name => tr(current_instance.name,"Name from database"))
    @ideas = @user.endorsements.active.by_position.find(:all, :include => :idea, :limit => 5)
    @endorsements = nil
    get_following
    if logged_in? # pull all their endorsements on the ideas shown
      @endorsements = Endorsement.find(:all, :conditions => ["idea_id in (?) and user_id = ? and status='active'", @ideas.collect {|c| c.idea_id},current_user.id])
    end    
    @activities = @user.activities.active.by_recently_created.paginate :include => :user, :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html
      format.xml { render :xml => @user.to_xml(:methods => [:revisions_count], :include => [:top_endorsement, :referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @user.to_json(:methods => [:revisions_count], :include => [:top_endorsement, :referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
    end
  end
  
  def ideas
    @user = User.find(params[:id])    
    redirect_to '/' and return if check_for_suspension
    @page_title = tr("{user_name} ideas at {instance_name}", "controller/users", :user_name => @user.name.possessive, :instance_name => tr(current_instance.name,"Name from database"))
    @ideas = @user.endorsements.active.by_position.paginate :include => :idea, :page => params[:page], :per_page => params[:per_page]
    @endorsements = nil
    get_following
    if logged_in? # pull all their endorsements on the ideas shown
      @endorsements = Endorsement.find(:all, :conditions => ["idea_id in (?) and user_id = ? and status='active'", @ideas.collect {|c| c.idea_id},current_user.id])
    end    
    respond_to do |format|
      format.html
      format.xml { render :xml => @ideas.to_xml(:include => [:idea], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ideas.to_json(:include => [:idea], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end
  
  def activities
    @user = User.find(params[:id])
    redirect_to '/' and return if check_for_suspension
    get_following
    @page_title = tr("What {user_name} is doing at {instance_name}", "controller/users", :user_name => @user.name, :instance_name => tr(current_instance.name,"Name from database"))
    @activities = @user.activities.active.by_recently_created.paginate :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html # show.html.erb
      format.rss { render :template => "rss/activities" }
      format.xml { render :xml => @activities.to_xml(:include => :comments, :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @activities.to_json(:include => :comments, :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end
  
  def comments
    @user = User.find(params[:id])
    redirect_to '/' and return if check_for_suspension
    @page_title = tr("{user_name} comments at {instance_name}", "controller/users", :user_name => @user.name.possessive, :instance_name => tr(current_instance.name,"Name from database"))
    @comments = @user.comments.published.by_recently_created.find(:all, :include => :activity).paginate :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.rss { render :template => "rss/comments" }
      format.xml { render :xml => @comments.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @comments.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end  
  
  def discussions
    @user = User.find(params[:id])
    redirect_to '/' and return if check_for_suspension
    get_following
    @page_title = tr("{user_name} discussions at {instance_name}", "controller/users", :user_name => @user.name.possessive, :instance_name => tr(current_instance.name,"Name from database"))
    @activities = @user.activities.active.discussions.by_recently_created.paginate :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html { render :template => "users/activities" }
      format.xml { render :xml => @activities.to_xml(:include => :comments, :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @activities.to_json(:include => :comments, :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end 
  
  def ads
    @user = User.find(params[:id])
    redirect_to '/' and return if check_for_suspension
    get_following
    @page_title = tr("{user_name} ads at {instance_name}", "controller/users", :user_name => @user.name.possessive, :instance_name => tr(current_instance.name,"Name from database"))
    @ads = @user.ads.active_first.paginate :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html # show.html.erb
      format.xml { render :xml => @ads.to_xml(:include => :idea, :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @ads.to_json(:include => :idea, :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end
  
  def capital
    @user = User.find(params[:id])
    redirect_to '/' and return if check_for_suspension
    get_following
    @page_title = tr("{user_name} {currency_name} at {instance_name}", "controller/users", :user_name => @user.name.possessive, :currency_name => tr(current_instance.currency_name.downcase,"Currency name from database"), :instance_name => tr(current_instance.name,"Name from database"))
    @activities = @user.activities.active.capital.by_recently_created.paginate :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html {
        render :template => "users/activities"
      }
      format.xml { render :xml => @activities.to_xml(:include => :capital, :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @activities.to_json(:include => :capital, :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end  
  
  def points
    @user = User.find(params[:id])
    redirect_to '/' and return if check_for_suspension
    get_following
    @page_title = tr("{user_name} points at {instance_name}", "controller/users", :user_name => @user.name.possessive, :instance_name => tr(current_instance.name,"Name from database"))
    @points = @user.points.published.by_recently_created.paginate :page => params[:page], :per_page => params[:per_page]
    if logged_in? and @points.any? # pull all their qualities on the points shown
      @qualities = PointQuality.find(:all, :conditions => ["point_id in (?) and user_id = ? ", @points.collect {|c| c.id},current_user.id])
    end    
    respond_to do |format|
      format.html
      format.xml { render :xml => @points.to_xml(:include => [:idea,:other_idea], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @points.to_json(:include => [:idea,:other_idea], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end
  
  def stratml
    @user = User.find(params[:id])
    @page_title = tr("{user_name} ideas at {instance_name}", "controller/users", :user_name => @user.name.possessive, :instance_name => tr(current_instance.name,"Name from database"))
    @tags = @user.issues(500)
    respond_to do |format|
      format.xml # show.html.erb
    end    
  end

  def create
    # cookies.delete :auth_token
    # protects against session fixation attacks, wreaks havoc with
    # request forgery protection.
    # uncomment at your own risk
    # reset_session
    @valid = true

    @user = User.new(params[:user]) 
    @user.request = request
    @user.referral = @referral
    @user.sub_instance_referral = current_sub_instance

    begin
      if Rails.env.test? && @user.save!
        @valid = true
      elsif verify_recaptcha(:model => @user, :message => tr("Please try reCAPTCHA again","users")) and @user.save! #save first
        @valid = true
      else
        @valid = false
      end
      rescue ActiveRecord::RecordInvalid
        @valid = false
    end   

    if not @valid
      respond_to do |format|
        format.js
        format.html { render :action => "new" }
      end
      return
    end
    self.current_user = @user # automatically log them in
    
    if current_sub_instance and params[:signup]
      @user.signups << Signup.create(:sub_instance => current_sub_instance, :is_optin => params[:signup][:is_optin], :ip_address => request.remote_ip)
    end
      
    flash[:notice] = tr("Welcome to {instance_name}", "controller/users", :instance_name => tr(current_instance.name,"Name from database"))
    if session[:query] 
      @send_to_url = "/?q=" + session[:query]
      session[:query] = nil
    else
      @send_to_url = session[:return_to] || get_previous_location
    end
    session[:goal] = 'signup'
    respond_to do |format|
      format.js
      format.html { redirect_to @send_to_url }
    end      
  end  

  def activate
    self.current_user = params[:activation_code].blank? ? false : User.find_by_activation_code(params[:activation_code])
    if logged_in? && !current_user.active?
      current_user.activate!
    end
    flash[:notice] = tr("Thanks for verifying your email address", "controller/users")
    redirect_back_or_default('/')
  end
  
  def resend_activation
    @user = User.find(params[:id])
    redirect_to '/' and return if check_for_suspension
    @user.resend_activation
    flash[:notice] = tr("Resent verification email to {email}", "controller/users", :email => @user.email)
    redirect_back_or_default(url_for(@user))
  end  

  def reset_password
    @user = User.find(params[:id])
    @user.reset_password
    flash[:notice] = tr("Sent a new temporary password to {email}", "controller/users", :email => @user.email)
    redirect_to @user
  end
  
  # POST /users/1/follow
  def follow
    @value = params[:value].to_i
    @user = User.find(params[:id])
    if @value == 1
      @following = current_user.follow(@user)
    else
      @following = current_user.ignore(@user)    
    end
    respond_to do |format|
      format.js {
        render :update do |page|
          if params[:region] == 'user_left'
            page.replace_html 'user_' + @user.id.to_s + "_button",render(:partial => "users/button_small", :locals => {:user => @user, :following => @following})
          end          
        end
      }    
    end  
  end

  # POST /users/1/unfollow
  def unfollow
    @value = params[:value].to_i
    @user = User.find(params[:id])
    if @value == 1
      current_user.unfollow(@user)
    else
      current_user.unignore(@user)    
    end
    respond_to do |format|
      format.js {
        render :update do |page|
          if params[:region] == 'user_left'
            page.replace_html 'user_' + @user.id.to_s + "_button",render(:partial => "users/button_small", :locals => {:user => @user, :following => nil})
          end          
        end
      }    
    end  
  end
  
  # GET /users/1/followers
  def followers
    @user = User.find(params[:id])
    redirect_to '/' and return if check_for_suspension
    get_following
    @page_title = tr("{count} people are following {user_name}", "controller/users", :user_name => @user.name, :count => @user.followers_count)      
    @followings = @user.followers.up.paginate :page => @page, :per_page => 50
    respond_to do |format|
      format.html
      format.xml { render :xml => @followings.to_xml(:include => [:user], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @followings.to_json(:include => [:user], :except => NB_CONFIG['api_exclude_fields']) }
    end
  end

  # GET /users/1/ignorers
  def ignorers
    @user = User.find(params[:id])
    redirect_to '/' and return if check_for_suspension
    get_following    
    @page_title = tr("{count} people are ignoring {user_name}", "controller/users", :user_name => @user.name, :count => @user.ignorers_count)      
    @followings = @user.followers.down.paginate :page => @page, :per_page => 50
    respond_to do |format|
      format.html { render :action => "followers" }
      format.xml { render :xml => @followings.to_xml(:include => [:user], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @followings.to_json(:include => [:user], :except => NB_CONFIG['api_exclude_fields']) }
    end
  end  
  
  # GET /users/1/following
  def following
    @user = User.find(params[:id])
    redirect_to '/' and return if check_for_suspension
    get_following
    @page_title = tr("{user_name} is following {count} people", "controller/users", :user_name => @user.name, :count => @user.followings_count)      
    @followings = @user.followings.up.paginate :page => @page, :per_page => 50
    respond_to do |format|
      format.html
      format.xml { render :xml => @followings.to_xml(:include => [:other_user], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @followings.to_json(:include => [:other_user], :except => NB_CONFIG['api_exclude_fields']) }
    end
  end

  # GET /users/1/ignoring
  def ignoring
    @user = User.find(params[:id])
    redirect_to '/' and return if check_for_suspension
    get_following    
    @page_title = tr("{user_name} is ignoring {count} people", "controller/users", :user_name => @user.name, :count => @user.ignorings_count)      
    @followings = @user.followings.down.paginate :page => @page, :per_page => 50
    respond_to do |format|
      format.html { render :action => "following" }
      format.xml { render :xml => @followings.to_xml(:include => [:other_user], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @followings.to_json(:include => [:other_user], :except => NB_CONFIG['api_exclude_fields']) }
    end
  end  

  # this is for loading up more endorsements in the left column
  def endorsements
    session[:endorsement_page] = (params[:page]||1).to_i
    respond_to do |format|
      format.js {
        render :update do |page|
          page.replace_html 'your_ideas_container', :partial => "ideas/yours"
        end
      }
    end
  end

  def order
    order = params[:your_ideas]
    endorsements = Endorsement.find(:all, :conditions => ["id in (?)", params[:your_ideas]], :order => "position asc")
    order.each_with_index do |id, position|
      if id
        endorsement = endorsements.detect {|e| e.id == id.to_i }
        new_position = (((session[:endorsement_page]||1)*25)-25)+position + 1
        if endorsement and endorsement.position != new_position
          endorsement.insert_at(new_position)
          endorsements = Endorsement.find(:all, :conditions => ["id in (?)", params[:your_ideas]], :order => "position asc")
        end
      end
    end
    respond_to do |format|
      format.js {
        render :update do |page|
          page.replace_html 'your_ideas_container', :partial => "ideas/yours"
          #page.replace_html 'your_ideas_container', order.inspect
        end
      }
    end
  end

   # DELETE /user
  def destroy
    @user = User.find(current_user.id)
    @user.remove!
    self.current_user.forget_me
    cookies.delete :auth_token
    reset_session
    flash[:notice] = tr("Your account was deleted. Good bye!", "controller/settings")
    redirect_to "/" and return
  end

  # PUT /users/1/suspend
  def suspend
    @user = User.find(params[:id])
    @user.suspend! 
    redirect_to(@user)
  end

  # PUT /users/1/unsuspend
  def unsuspend
    @user = User.find(params[:id])
    @user.unsuspend!
    flash[:notice] = tr("{user_name} has been reinstated", "controller/users", :user_name => @user.name)
    redirect_to request.referer
  end

  # this isn't actually used, but the current_user will endorse ALL of this user's ideas
  def endorse
    if not logged_in?
      session[:endorse_user] = params[:id]
      access_denied
      return
    end
    @user = User.find(params[:id])
    for e in @user.endorsements.active
      e.idea.endorse(current_user,request,current_sub_instance,@referral) if e.is_up?
      e.idea.oppose(current_user,request,current_sub_instance,@referral) if e.is_down?
    end
    respond_to do |format|
      format.js { redirect_from_facebox(user_path(@user)) }        
    end    
  end
  
  def impersonate
    @user = User.find(params[:id])
    self.current_user = @user
    flash[:notice] = tr("You are now logged in as {user_name}", "controller/users", :user_name => @user.name)
    redirect_to @user
    return
  end
  
  def make_admin
    redirect_to '/' and return
    @user = User.find(params[:id])
    @user.is_admin = true
    @user.save(:validate => false)
    flash[:notice] = tr("{user_name} is now an Administrator", "controller/users", :user_name => @user.name)
    redirect_to @user
  end
  
  private
  
    def get_following
      if logged_in?
        @following = @user.followers.find_by_user_id(current_user.id)      
      else
        @following = nil
      end
    end
    
    def check_for_suspension
      if @user.status == 'suspended'
        flash[:error] = tr("{user_name} is suspended", "controller/users", :user_name => @user.name)
        if logged_in? and current_user.is_admin?
        else
          return true
        end
      end
      if @user.status == 'removed'
        flash[:error] = tr("That user deleted their account", "controller/users")
        return true
      end
    end
  
end
