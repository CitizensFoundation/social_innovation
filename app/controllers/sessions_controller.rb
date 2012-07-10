# This controller handles the login/logout function of the site.  
class SessionsController < ApplicationController
  skip_before_filter :check_idea
  skip_before_filter :check_referral
  skip_before_filter :check_suspension
  skip_before_filter :update_loggedin_at
  skip_before_filter :check_blast_click

  def new
    @page_title = tr("Please sign in", "controller/sessions", :instance_name => tr(current_instance.name,"Name from database"))
    @user = User.new
    @signup = Signup.new    
    respond_to do |format|
      format.html
      format.js { render_to_facebox }
    end
  end

  def create
    Rails.logger.debug("BLAH -5: #{session[:return_to]}")
    self.current_user = User.authenticate(params[:email], params[:password])
    respond_to do |format|
        format.html {
          if logged_in?
            if params[:remember_me] == "1"
              current_user.remember_me unless current_user.remember_token?
              cookies[:auth_token] = { :value => self.current_user.remember_token , :expires => self.current_user.remember_token_expires_at }
            end
            redirect_back_or_default('/')
            flash[:notice] = tr("Welcome back, {user_name}.", "controller/sessions", :user_name => current_user.name)
          else
            flash[:error] = tr("You were NOT signed in, please check your name and password, or click on the 'I forgot my password' to get a new password.", "controller/sessions")
            render :action => 'new'
          end          
        }
        format.js {
          Rails.logger.debug("BLAH -4: #{session[:return_to]}")
          if logged_in?
            Rails.logger.debug("BLAH -3: #{session[:return_to]}")
            if session[:idea_id] # they were trying to endorse a idea, so let's go ahead and add it and take htem to their ideas page immediately
              Rails.logger.debug("BLAH -2: #{session[:return_to]}")
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
            Rails.logger.debug("BLAH -1: #{session[:return_to]}")
            flash[:notice] = tr("Welcome back, {user_name}.", "controller/sessions", :user_name => current_user.name) 
            current_user.remember_me unless current_user.remember_token?
            cookies[:auth_token] = { :value => self.current_user.remember_token , :expires => self.current_user.remember_token_expires_at }
            Rails.logger.debug("BLAH: #{session[:return_to]}")
            redirect_from_facebox(session[:return_to] ? session[:return_to] : "/")
          else
            render partial: 'login_failed'
            #if params[:region] == 'inline'
            #  render :update do |page|
            #    page.replace_html 'login_message', tr("Oops, try again.", "controller/sessions")
            #  end
            #else
            #  flash[:error] = tr("Oops, try again.", "controller/sessions")
            #  render_to_facebox(:action => "new")
            #end
          end          
        }
    end        
  end

  def destroy
    self.current_user.forget_me if logged_in?
    cookies.delete :auth_token
    cookies.delete "fbs_#{Facebooker2.app_id}"
    reset_session
    Thread.current[:current_user] = nil
    flash[:notice] = tr("Logged out. Please come again soon.", "controller/sessions")
    redirect_back_or_default('/')
  end
  
end
