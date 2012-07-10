class SubInstancesController < ApplicationController

  before_filter :login_required
  before_filter :admin_required, :only => [:destroy]

  def index
    @page_title = tr("SubInstance with {instance_name}", "controller/sub_instances", :instance_name => tr(current_instance.name,"Name from database"))
#    if logged_in? and current_user.attribute_present?("sub_instance_id")
#      redirect_to 'http://' + current_user.sub_instance.short_name + '.' + current_instance.base_url + edit_sub_instance_path(current_user.sub_instance)
#    end
    @sub_instance = SubInstance.new
  end
  
  def signup
    @signup = Signup.new(:is_optin => true)
  end

  # GET /sub_instances/1
  # GET /sub_instances/1.xml
  def show
    @sub_instance = SubInstance.find(params[:id])
    @page_title = @sub_instance.name
    respond_to do |format|
      format.html # show.html.erb
      format.xml { render :xml => @sub_instance.to_xml(:except => NB_CONFIG['api_exclude_fields']) }
      format.json { render :json => @sub_instance.to_json(:except => NB_CONFIG['api_exclude_fields']) }
    end
  end

  # GET /sub_instances/new
  # GET /sub_instances/new.xml
  def new
    @page_title = tr("SubInstance with {instance_name}", "controller/sub_instances", :instance_name => tr(current_instance.name,"Name from database"))
    @sub_instance = SubInstance.new
    respond_to do |format|
      format.html # new.html.erb
    end
  end

  # GET /sub_instances/1/edit
  def edit
    @sub_instance = SubInstance.find(params[:id])
    @page_title = tr("SubInstance settings", "controller/sub_instances")
  end

  # GET /sub_instances/1/email
  def email
    @sub_instance = SubInstance.find(params[:id])
    @page_title = tr("Email list settings", "controller/sub_instances")
  end

  # POST /sub_instances
  # POST /sub_instances.xml
  def create
    @sub_instance = SubInstance.new(params[:sub_instance])
    @sub_instance.ip_address = request.remote_ip
    @page_title = tr("SubInstance with {instance_name}", "controller/sub_instances", :instance_name => tr(current_instance.name,"Name from database"))
    respond_to do |format|
      if @sub_instance.save
        #@sub_instance.register!
        current_user.update_attribute(:sub_instance_id,@sub_instance.id)
        #@sub_instance.activate!
        flash[:notice] = tr("Thanks for sub_instanceing with us!", "controller/sub_instances")
        session[:goal] = 'sub_instance'
        format.html { redirect_to 'http://' + @sub_instance.short_name + '.' + current_instance.base_url + picture_sub_instance_path(@sub_instance)}
      else
        format.html { render :action => "new" }
      end
    end
  end

  # PUT /sub_instances/1
  # PUT /sub_instances/1.xml
  def update
    @sub_instance = SubInstance.find(params[:id])
    @page_title = tr("SubInstance settings", "controller/sub_instances")
    respond_to do |format|
      if @sub_instance.update_attributes(params[:sub_instance])
        flash[:notice] = tr("Saved settings", "controller/sub_instances")
        format.html { 
          if not @sub_instance.has_picture?
            redirect_to picture_sub_instance_path(@sub_instance)
          elsif params[:sub_instance][:name]
            redirect_to :action => "edit"
          else
            redirect_to :action => "email"
          end
        }
      else
        format.html { 
          if params[:sub_instance][:name]
            render :action => "edit" 
          else # send them to the sub_instance email update
            render :action => "email"
          end
        }
      end
    end
  end
  
  def picture
    @sub_instance = SubInstance.find(params[:id])
    @page_title = tr("Upload sub_instance logo", "controller/sub_instances")
  end

  def picture_save
    @sub_instance = SubInstance.find(params[:id])
    respond_to do |format|
      if @sub_instance.update_attributes(params[:sub_instance])
        flash[:notice] = tr("Picture uploaded successfully", "controller/sub_instances")
        format.html { redirect_to(:action => :picture) }
      else
        format.html { render :action => "picture" }
      end
    end
  end

  # DELETE /sub_instances/1
  # DELETE /sub_instances/1.xml
  def destroy
    @sub_instance = SubInstance.find(params[:id])
    @sub_instance.destroy

    respond_to do |format|
      format.html { redirect_to(sub_instances_url) }
    end
  end

end
