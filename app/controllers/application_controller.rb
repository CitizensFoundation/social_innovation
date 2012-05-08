# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require 'will_paginate/array'

class ApplicationController < ActionController::Base
  #include Tr8n::CommonMethods
  include AuthenticatedSystem
  include FaceboxRender

  include Facebooker2::Rails::Controller

  require_dependency "activity.rb"
  require_dependency "relationship.rb"   
  require_dependency "capital.rb"

#  rescue_from ActionController::InvalidAuthenticityToken, :with => :bad_token

  helper :all # include all helpers, all the time
  
  # Make these methods visible to views as well
  helper_method :current_facebook_user, :instance_cache, :current_sub_instance, :current_user_endorsements, :current_idea_ids, :current_following_ids, :current_ignoring_ids, :current_following_facebook_uids, :current_instance, :current_tags, :facebook_session, :is_robot?, :js_help
  
  # switch to the right database for this instance
  before_filter :check_for_localhost
  before_filter :check_subdomain
  before_filter :check_geoblocking

  before_filter :session_expiry
  before_filter :update_activity_time

  before_filter :load_actions_to_publish, :unless => [:is_robot?]
#  before_filter :check_facebook, :unless => [:is_robot?]
    
  before_filter :check_blast_click, :unless => [:is_robot?]
  before_filter :check_idea, :unless => [:is_robot?]
  before_filter :check_referral, :unless => [:is_robot?]
  before_filter :check_suspension, :unless => [:is_robot?]
  before_filter :update_loggedin_at, :unless => [:is_robot?]
  before_filter :init_tr8n
  before_filter :check_google_translate_setting
  before_filter :check_missing_user_parameters, :except=>[:destroy]

  before_filter :setup_inline_translation_parameters

  layout :get_layout

  protect_from_forgery

  protected

  JS_ESCAPE_MAP = {
        '\\'    => '\\\\',
        '</'    => '<\/',
        "\r\n"  => '\n',
        "\n"    => '\n',
        "\r"    => '\n',
        '"'     => '\\"',
        "'"     => "\\'" }
 
  def action_cache_path
    params.merge({:geoblocked=>@geoblocked, :host=>request.host, :country_code=>@country_code,
                  :locale=>session[:locale], :google_translate=>session[:enable_google_translate],
                  :have_shown_welcome=>session[:have_shown_welcome], 
                  :last_selected_language=>cookies[:last_selected_language],
                  :flash=>flash.map {|k,v| "#{v}" }.join.parameterize})
  end

  def do_action_cache?
    if logged_in?
      false
    elsif request.format.html?
      true
    else
      false
    end
  end
  
  def check_missing_user_parameters
    if logged_in? and Instance.current and Instance.current.layout == "better_reykjavik" and controller_name!="settings"
      unless current_user.email and current_user.my_gender and current_user.post_code and current_user.age_group
        flash[:notice] = "Please make sure you have registered all relevant information about you for this website."
        if request.format.js?
          render :update do |page|
            page.redirect_to :controller => "settings"
          end
          return false
        else
          redirect_to :controller=>"settings"
        end
      end
    end
  end

  def check_for_localhost
    if Rails.env.development?
      Thread.current[:localhost_override] = "#{request.host}:#{request.port}"
    end
  end

  def session_expiry
    return if controller_name == "sessions"
    Rails.logger.info("Session expires at #{session[:expires_at]}")
    if session[:expires_at]
      @time_left = (session[:expires_at] - Time.now).to_i
      if current_user and not current_facebook_user_if_on_facebook
        unless @time_left > 0
          Rails.logger.info("Resetting session")
          reset_session
          flash[:error] = tr("Your session has expired, please login again.","session")
          redirect_to '/'
        end
      end
    end
  end
  
  def update_activity_time
    if current_user and current_user.is_admin?
      session[:expires_at] = 6.hours.from_now
    else
      session[:expires_at] = 1.hour.from_now
    end
  end

  def setup_inline_translation_parameters
    @inline_translations_allowed = false
    @inline_translations_enabled = false

    if logged_in? and Tr8n::Config.current_user_is_translator?
      unless Tr8n::Config.current_translator.blocked?
        @inline_translations_allowed = true
        @inline_translations_enabled = Tr8n::Config.current_translator.enable_inline_translations?
      end
    elsif logged_in?
      @inline_translations_allowed = Tr8n::Config.open_registration_mode?
    end

    @inline_translations_allowed = true if Tr8n::Config.current_user_is_admin?
  end
        
  def unfrozen_instance(object)
    eval "#{object.class}.where(:id=>object.id).first"
  end
        
  def escape_javascript(javascript)
    if javascript
      javascript.gsub(/(\\|<\/|\r\n|[\n\r"'])/) { JS_ESCAPE_MAP[$1] }
    else
      ''
    end
  end  

  # Will either fetch the current sub_instance or return nil if there's no subdomain
  def current_sub_instance
    if Rails.env.development?
      begin
        if params[:sub_instance_short_name]
          if params[:sub_instance_short_name].empty?
            session.delete(:set_sub_instance_id)
            SubInstance.current = @current_sub_instance = nil
          else
            @current_sub_instance = SubInstance.find_by_short_name(params[:sub_instance_short_name])
            SubInstance.current = @current_sub_instance
            session[:set_sub_instance_id] = @current_sub_instance.id
          end
        elsif session[:set_sub_instance_id]
          @current_sub_instance = SubInstance.find(session[:set_sub_instance_id])
          SubInstance.current = @current_sub_instance
        end
      end
    end
    @current_sub_instance ||= SubInstance.find_by_short_name(request.subdomains.first)
    @current_sub_instance ||= SubInstance.first
    SubInstance.current = @current_sub_instance
  end
  
  def check_geoblocking
    if File.exists?(Rails.root.join("lib/geoip/GeoIP.dat"))
      @country_code = Thread.current[:country_code] = (session[:country_code] ||= GeoIP.new(Rails.root.join("lib/geoip/GeoIP.dat")).country(request.remote_ip)[3]).downcase
    else
      Rails.logger.error "No GeoIP.dat file"
    end
    @country_code = "is" if @country_code == nil or @country_code == "--"
    @iso_country = Tr8n::IsoCountry.find_by_code(@country_code.upcase)
    Rails.logger.info("Geoip country: #{@country_code} - locale #{session[:locale]} - #{current_user ? (current_user.email ? current_user.email : current_user.login) : "Anonymous"}")
    Rails.logger.info(request.user_agent)
    if SubInstance.current and SubInstance.current.geoblocking_enabled
      logged_in_user = current_user
      unless SubInstance.current.geoblocking_disabled_for?(@country_code)
        Rails.logger.info("Geoblocking enabled")
        @geoblocked = true unless Rails.env.development? or (current_user and current_user.is_admin?)
      end
      if logged_in_user and logged_in_user.geoblocking_disabled_for?(SubInstance.current)
        Rails.logger.info("Geoblocking disabled for user #{logged_in_user.login}")
        @geoblocked = false
      end
    end
    if @geoblocked
      unless session["have_shown_geoblock_warning_#{@country_code}"]
        flash.now[:notice] = tr("This part of the website is only open for viewing in your country.","geoblocking")
        session["have_shown_geoblock_warning_#{@country_code}"] = true
      end
    end
  end
  
  def current_locale
    if params[:locale]
      session[:locale] = params[:locale]
      cookies.permanent[:last_selected_language] = session[:locale]
      Rails.logger.debug("Set language from params")
    elsif not session[:locale]
      if cookies[:last_selected_language]
        session[:locale] = cookies[:last_selected_language]
        Rails.logger.debug("Set language from cookie")
      elsif Instance.current.layout == "better_reykjavik"
        session[:locale] = "is"
        Rails.logger.info("Set language from better reykjavik")
      elsif Instance.current.layout == "better_iceland"
        session[:locale] = "is"
        Rails.logger.info("Set language from better iceland")
      elsif Instance.current.layout == "application"
        session[:locale] = "en"
        Rails.logger.info("Set language for application to English")
      elsif @iso_country and not @iso_country.languages.empty?
        session[:locale] =  @iso_country.languages.first.locale
        Rails.logger.debug("Set language from geoip")
      elsif SubInstance.current and SubInstance.current.default_locale
        session[:locale] = SubInstance.current.default_locale
        Rails.logger.debug("Set language from sub_instance")
      else
        session[:locale] = tr8n_user_preffered_locale
        Rails.logger.debug("Set language from tr8n")
      end
    else
      Rails.logger.debug("Set language from session")
    end
    session_locale = session[:locale]
    if ENABLED_I18_LOCALES.include?(session_locale)
      I18n.locale = session_locale
    else
      session_locale = session_locale.split("-")[0] if session_locale.split("-").length>1
      I18n.locale = ENABLED_I18_LOCALES.include?(session_locale) ? session_locale : "en"
    end
    tr8n_current_locale = session[:locale]
  end

  def check_google_translate_setting
    if params[:gt]
      if params[:gt]=="1"
        session[:enable_google_translate] = true
      else
        session[:enable_google_translate] = nil
      end
    end
    
    @google_translate_enabled_for_locale = Tr8n::Config.current_language.google_key
  end
  
  def get_layout
    return false if not is_robot? and not current_instance
    return "basic" if not Instance.current
    return "hverfapottar_main" if controller_name == "about" and action_name=="show" and params[:id] == 'choose_sub_instance'
    return Instance.current.layout
  end

  def current_instance
    return @current_instance if @current_instance
    @current_instance = Rails.cache.read('instance')
    if not @current_instance
      @current_instance = Instance.last
      if @current_instance
        @current_instance.update_counts
        Rails.cache.write('instance', @current_instance, :expires_in => 15.minutes)
      else
        return nil
      end
    end
    Instance.current = @current_instance
    return @current_instance
  end
  
  def current_user_endorsements
		@current_user_endorsements ||= current_user.endorsements.active.by_position.paginate(:include => :idea, :page => session[:endorsement_page], :per_page => 25)
  end
  
  def current_idea_ids
    return [] unless logged_in? and current_user.endorsements_count > 0
    @current_idea_ids ||= current_user.endorsements.active_and_inactive.collect{|e|e.idea_id}
  end  
  
  def current_following_ids
    return [] unless logged_in? and current_user.followings_count > 0
    @current_following_ids ||= current_user.followings.up.collect{|f|f.other_user_id}
  end
  
  def current_following_facebook_uids
    return [] unless logged_in? and current_user.followings_count > 0 and current_user.has_facebook?
    @current_following_facebook_uids ||= current_user.followings.up.collect{|f|f.other_user.facebook_uid}.compact
  end  
  
  def current_ignoring_ids
    return [] unless logged_in? and current_user.ignorings_count > 0
    @current_ignoring_ids ||= current_user.followings.down.collect{|f|f.other_user_id}    
  end
  
  def current_tags
    return [] unless current_instance.is_tags?
    @current_tags ||= Rails.cache.fetch('Tag.by_endorsers_count.all') { Tag.by_endorsers_count.all }
  end

  def load_actions_to_publish
    @user_action_to_publish = flash[:user_action_to_publish] 
    flash[:user_action_to_publish]=nil
  end  
  
  def check_suspension
    if logged_in? and current_user and current_user.status == 'suspended'
      self.current_user.forget_me if logged_in?
      cookies.delete :auth_token
      reset_session
      flash[:notice] = "This account has been suspended."
      redirect_back_or_default('/')
      return  
    end
  end
  
  # they were trying to endorse a idea, so let's go ahead and add it and take htem to their ideas page immediately
  def check_idea
    return unless logged_in? and session[:idea_id]
    @idea = Idea.find(session[:idea_id])
    @value = session[:value].to_i
    if @idea
      if @value == 1
        @idea.endorse(current_user,request,current_sub_instance,@referral)
      else
        @idea.oppose(current_user,request,current_sub_instance,@referral)
      end
    end  
    session[:idea_id] = nil
    session[:value] = nil
  end
  
  def update_loggedin_at
    return unless logged_in?
    return unless current_user.loggedin_at.nil? or Time.now > current_user.loggedin_at+30.minutes
    begin
      User.find(current_user.id).update_attribute(:loggedin_at,Time.now)
    rescue
    end
  end

  def check_blast_click
    # if they've got a ?b= code, log them in as that user
    if params[:b] and params[:b].length > 2
      @blast = Blast.find_by_code(params[:b])
      if @blast and not logged_in?
        self.current_user = @blast.user
        @blast.increment!(:clicks_count)
      end
      redirect = request.path_info.split('?').first
      redirect = "/" if not redirect
      redirect_to redirect
      return
    end
  end

  def check_subdomain
    if not current_instance
      redirect_to :controller => "install"
      return
    end
    if not current_sub_instance and Rails.env == 'production' and request.subdomains.any? and not ['www','dev'].include?(request.subdomains.first) and current_instance.base_url != request.host
      redirect_to 'http://' + current_instance.base_url + request.path_info
      return
    end    
  end
  
  def check_referral
    if not params[:referral_id].blank?
      @referral = User.find(params[:referral_id])
    else
      @referral = nil
    end    
  end  

  def current_facebook_user_if_on_facebook
    ret_user = nil
    begin
      ret_user = current_facebook_user
    rescue Mogli::Client::OAuthException
      return nil
    end
    ret_user
  end

  # if they're logged in with our account, AND connected with facebook, but don't have their facebook uid added to their account yet
  def check_facebook 
    if logged_in? and current_facebook_user_if_on_facebook
      unless current_user.facebook_uid
        @user = User.find(current_user.id)
        if not @user.update_with_facebook(current_facebook_user)
          return
        end
        if not @user.activated?
          @user.activate!
        end      
        @current_user = User.find(current_user.id)
        flash.now[:notice] = tr("Your account is now synced with Facebook. In the future, to sign in, simply click the big blue Facebook button.", "controller/application", :instance_name => tr(current_instance.name,"Name from database"))
      end
    end      
  end
  
  def is_robot?
    return true if request.format == 'rss' or params[:controller] == 'pictures'
    request.user_agent =~ /\b(Baidu|Gigabot|Googlebot|libwww-perl|lwp-trivial|msnbot|SiteUptime|Slurp|WordPress|ZIBB|ZyBorg)\b/i
  end
  
  def no_facebook?
    return false if logged_in? and current_facebook_user_if_on_facebook
    return true
  end
  
  def bad_token
    flash[:error] = tr("Sorry, that last page already expired. Please try what you were doing again.", "controller/application")
    respond_to do |format|
      format.html { redirect_to request.referrer||'/' }
      format.js { redirect_from_facebox(request.referrer||'/') }
    end
  end
  
  def fb_session_expired
    self.current_user.forget_me if logged_in?
    cookies.delete :auth_token
    reset_session    
    flash[:error] = tr("Your Facebook session expired.", "controller/application")
    respond_to do |format|
      format.html { redirect_to '/portal/' }
      format.js { redirect_from_facebox(request.referrer||'/') }
    end    
  end
  
  def js_help
    JavaScriptHelper.instance
  end

  class JavaScriptHelper
    include Singleton
    include ActionView::Helpers::JavaScriptHelper
  end

  def setup_filter_dropdown
    setup_menu_items
    @sub_menu_items = @items
    Rails.logger.debug action_name

    if action_name == "index" and @items and not request.xhr?
      Rails.logger.debug "index"
      selected = cookies["selected_#{controller_name}_filter_id"].to_i
      Rails.logger.debug "cookie #{selected}"
      if selected and @sub_menu_items[selected]
        Rails.logger.debug "cookie"
        redirect_to @sub_menu_items[selected][1]
        return false
      else
        Rails.logger.debug "no cookie"
        redirect_to @sub_menu_items[1][1]
        return false
      end
    end

    selected_sub_menu_item_id, selected_sub_menu_item = find_menu_item_by_url(request.url)
    if selected_sub_menu_item
      @selected_sub_nav_name = selected_sub_menu_item[0]
      Rails.logger.debug "Saved submenu id #{selected_sub_menu_item_id}"
      @selected_sub_nav_item_id = cookies["selected_#{controller_name}_filter_id"] = selected_sub_menu_item_id
    end
  end

  def find_menu_item_by_url(url)
    @items.each do |id,item|
      if url =~ /\A#{item[1]}(\?.*)?\z/
        return id,item
        break
      end
    end
  end
end