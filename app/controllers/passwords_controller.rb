class PasswordsController < ApplicationController

  before_filter :login_from_cookie
  before_filter :login_required, :except => [:create, :new]
  before_filter :current_user_required, :only => [:edit, :update]

  # POST /passwords
  # Forgot password
  
  # If a user is logged in and they want to change their password
  # link to edit_user_path(current_user). 
  # If a user is not logged in and has forgotten their password, 
  # link to the forgot password view by using new_password_path().  
  
  def new
    @page_title = tr("Reset your {instance_name} password", "controller/passwords", :instance_name => tr(current_instance.name,"Name from database"))
  end
  
  def create
    @page_title = tr("Reset your {instance_name} password", "controller/passwords", :instance_name => tr(current_instance.name,"Name from database"))
    users = User.find(:all, :conditions => ["email = ? and status in ('active','pending','passive')",params[:email]])
    if users.any?
      user = users[0]
      if user.has_facebook?
        flash[:error] = tr("Your password is handled on Facebook, not at {instance_name}. Click the Facebook button to sign in.", "controller/passwords", :instance_name => tr(current_instance.name,"Name from database"))
        redirect_to :action => "new"
        return
      else
        user.reset_password
        flash[:notice] = tr("Sent a new temporary password to {email}", "controller/passwords", :email => user.email)
        redirect_to login_path
        return
      end      
    else
      user = nil
      flash[:error] =  tr("Could not find that member", "controller/passwords")
      redirect_to :action => "new"
      return
    end
  end

  # GET /users/1/password/edit
  # Changing password
  def edit
    @page_title = tr("Change your {instance_name} password", "controller/passwords", :instance_name => tr(current_instance.name,"Name from database"))
    @user = current_user
    if @user.has_facebook?
      flash[:error] = tr("Your password is the same as your Facebook password, so you must change it on Facebook.", "controller/passwords", :instance_name => tr(current_instance.name,"Name from database"))
      return
    end
  end

  # PUT /users/1/password
  # Changing password
  def update
    @user = current_user
    old_password = params[:old_password]
    @user.attributes = params[:user]

    respond_to do |format|
      if @user.authenticated?(old_password) && @user.save
        flash[:notice] = tr("Password changed", "controller/passwords")
        format.html { redirect_to edit_password_url(@user) }
      else
        flash[:error] = tr("Password confirmation did not match", "controller/passwords")
        format.html { render :action => 'edit' }
      end
    end
  end

end
