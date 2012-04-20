class ChartsController < ApplicationController

  def issues
    @page_title = tr("Most active {tags_name} at {instance_name}", "controller/charts", :tags_name => current_instance.tags_name.pluralize.downcase, :instance_name => tr(current_instance.name,"Name from database"))
    respond_to do |format|
      format.html
    end    
  end

  def gainers_24hr
    @page_title = tr("People with the fastest rising ideas in the last 24 hours", "controller/charts")
    @users = User.active.by_24hr_gainers.paginate :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html
      format.xml { render :xml => @users.to_xml(:include => [:top_endorsement, :referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @users.to_json(:include => [:top_endorsement, :referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end  
  
  def gainers_7days
    @page_title = tr("People with the fastest rising ideas this week", "controller/charts")
    @users = User.active.by_7days_gainers.paginate :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html
      format.xml { render :xml => @users.to_xml(:include => [:top_endorsement, :referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @users.to_json(:include => [:top_endorsement, :referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end
  
  def gainers_30days
    @page_title = tr("People with the fastest rising ideas this month", "controller/charts")
    @users = User.active.by_30days_gainers.paginate :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html
      format.xml { render :xml => @users.to_xml(:include => [:top_endorsement, :referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @users.to_json(:include => [:top_endorsement, :referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end    
  
  def losers_24hr
    @page_title = tr("People with the fastest falling ideas in the last 24 hours", "controller/charts")
    @users = User.active.by_24hr_losers.paginate :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html 
      format.xml { render :xml => @users.to_xml(:include => [:top_endorsement, :referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @users.to_json(:include => [:top_endorsement, :referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end  
  
  def losers_7days
    @page_title = tr("People with the fastest falling ideas this week", "controller/charts")
    @users = User.active.by_7days_losers.paginate :page => params[:page], :per_page => params[:per_page]
    respond_to do |format|
      format.html
      format.xml { render :xml => @users.to_xml(:include => [:top_endorsement, :referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @users.to_json(:include => [:top_endorsement, :referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end

  def losers_30days
    @page_title = tr("People with the fastest falling ideas this month", "controller/charts")
    @users = User.active.by_30days_losers.paginate :page => params[:page], :per_page => params[:per_page]
    respond_to do |format| 
      format.html 
      format.xml { render :xml => @users.to_xml(:include => [:top_endorsement, :referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @users.to_json(:include => [:top_endorsement, :referral, :sub_instance_referral], :except => NB_CONFIG['api_exclude_fields']) }
    end    
  end


end
