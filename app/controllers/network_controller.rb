class NetworkController < ApplicationController
  
  before_filter :login_required, :only => [:find]
  before_filter :admin_required, :only => [:unverified, :deleted, :suspended, :probation, :warnings]
  before_filter :setup, :except => [:sub_instance]

  caches_action :index, :talkative, :ambassadors, :newest,
                :if => proc {|c| c.do_action_cache? },
                :cache_path => proc {|c| c.action_cache_path},
                :expires_in => 5.minutes
  
  def index
    @page_title = tr("Meet the most influential people at {instance_name}", "controller/network", :instance_name => tr(current_instance.name,"Name from database"))
    if current_instance.users_count < 100
      @users = User.active.at_least_one_endorsement.by_capital.paginate :page => params[:page], :per_page => params[:per_page]
    else
      @users = User.active.at_least_one_endorsement.by_ranking.paginate :page => params[:page], :per_page => params[:per_page]
    end
    respond_to do |format|
      format.html
      format.xml { render :xml => @users.to_xml(:include => [:top_endorsement, :referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @users.to_json(:include => [:top_endorsement, :referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end

  def talkative
    @page_title = tr("Most talkative at {instance_name}", "controller/network", :instance_name => tr(current_instance.name,"Name from database"))
    @users = User.active.by_talkative.paginate :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html
      format.xml { render :xml => @users.to_xml(:include => [:top_endorsement, :referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @users.to_json(:include => [:top_endorsement, :referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end  
  
  def ambassadors
    @page_title = tr("Ambassadors at {instance_name}", "controller/network", :instance_name => tr(current_instance.name,"Name from database"))
    @users = User.active.by_invites_accepted.paginate :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html
      format.xml { render :xml => @users.to_xml(:include => [:top_endorsement, :referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @users.to_json(:include => [:top_endorsement, :referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end  
  
  def twitterers
    @page_title = tr("Twitterers at {instance_name}", "controller/network", :instance_name => tr(current_instance.name,"Name from database"))
    @users = User.active.at_least_one_endorsement.twitterers.by_twitter_count.paginate :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html
      format.xml { render :xml => @users.to_xml(:include => [:top_endorsement, :referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @users.to_json(:include => [:top_endorsement, :referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end  

  def unverified
    @page_title = tr("Unverified accounts", "controller/network", :instance_name => tr(current_instance.name,"Name from database"))
    @users = User.pending.by_recently_created.paginate :page => params[:page], :per_page => 100
    respond_to do |format|
      format.html { render :action => "list" }
      format.xml { render :xml => @users.to_xml(:include => [:referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @users.to_json(:include => [:referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end
  
  def warnings
    @page_title = tr("Warnings", "controller/network", :instance_name => tr(current_instance.name,"Name from database"))
    @users = User.warnings.by_recently_loggedin.paginate :page => params[:page], :per_page => 100
    respond_to do |format|
      format.html
      format.xml { render :xml => @users.to_xml(:include => [:referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @users.to_json(:include => [:referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end

  def suspended
    @page_title = tr("Suspended accounts", "controller/network", :instance_name => tr(current_instance.name,"Name from database"))
    @users = User.suspended.by_suspended_at.paginate :page => params[:page], :per_page => 100
    respond_to do |format|
      format.html { render :action => "list" }
      format.xml { render :xml => @users.to_xml(:include => [:referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @users.to_json(:include => [:referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end
  
  def probation
    @page_title = tr("Accounts on probation", "controller/network", :instance_name => tr(current_instance.name,"Name from database"))
    @users = User.probation.by_probation_at.paginate :page => params[:page], :per_page => 100
    respond_to do |format|
      format.html { render :action => "list" }
      format.xml { render :xml => @users.to_xml(:include => [:referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @users.to_json(:include => [:referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end  
  
  def deleted
    @page_title = tr("Deleted accounts", "controller/network", :instance_name => tr(current_instance.name,"Name from database"))
    @users = User.deleted.by_deleted_at.paginate :page => params[:page], :per_page => 100
    respond_to do |format|
      format.html { render :action => "list" }
      format.xml { render :xml => @users.to_xml(:include => [:referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @users.to_json(:include => [:referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end  

  def newest
    @page_title = tr("New members at {instance_name}", "controller/network", :instance_name => tr(current_instance.name,"Name from database"))
    @users = User.active.at_least_one_endorsement.by_recently_created.paginate :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html
      format.xml { render :xml => @users.to_xml(:include => [:top_endorsement, :referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @users.to_json(:include => [:top_endorsement, :referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end

  def find
    redirect_to user_contacts_path(current_user)
    return
  end

  def search
    @user = User.find_by_login(params[:user][:login])
    if @user
      redirect_to @user 
    else
      flash[:error] = tr("Could not find that member", "controller/network")
      redirect_to :controller => "network"
    end
  end
  
  def sub_instances
    if User.adapter == 'postgresql'
      @sub_instances = Partner.find(:all, :conditions => "logo_file_name is not null", :order => "RANDOM()")
    else
      @sub_instances = Partner.find(:all, :conditions => "logo_file_name is not null", :order => "rand()")
    end
    @page_title = tr("Meet our sub_instances", "controller/network", :instance_name => tr(current_instance.name,"Name from database"))
    respond_to do |format|
      format.html
      format.xml { render :xml => @sub_instances.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @sub_instances.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end  

  private
  def setup
    @user = User.new
    @row = (params[:page].to_i-1)*25
    @row = 0 if params[:page].to_i <= 1
  end 

end

