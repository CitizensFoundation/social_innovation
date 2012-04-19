class ColorSchemesController < ApplicationController
  # GET /color_schemes
  # GET /color_schemes.xml
  def index
    @page_title = tr("Choose a color theme", "controller/schemes", :instance_name => tr(current_instance.name,"Name from database"))
    @color_schemes = ColorScheme.featured.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @color_schemes }
    end
  end

  # GET /color_schemes/1
  # GET /color_schemes/1.xml
  def show
    @color_scheme = ColorScheme.find(params[:id])
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @color_scheme }
    end
  end

  # GET /color_schemes/new
  # GET /color_schemes/new.xml
  def new
    @page_title = tr("Design for {instance_name}", "controller/schemes", :instance_name => tr(current_instance.name,"Name from database"))
    if params[:id]
      find = ColorScheme.find(params[:id]) 
      @color_scheme = find.clone if find
    else
      @color_scheme = current_instance.color_scheme.clone
    end
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @color_scheme }
    end
  end

  # GET /color_schemes/1/edit
  def edit
    @color_scheme = ColorScheme.find(params[:id])
  end

  # POST /color_schemes
  # POST /color_schemes.xml
  def create
    @page_title = tr("Design for {instance_name}", "controller/schemes", :instance_name => tr(current_instance.name,"Name from database"))
    @color_scheme = ColorScheme.new(params[:color_scheme])
    respond_to do |format|
      if @color_scheme.save
        current_instance.update_attribute(:color_scheme_id, @color_scheme.id)
        flash[:notice] = tr("Saved color scheme", "controller/schemes")
        format.html { redirect_to(new_color_scheme_url(:id => @color_scheme)) }
        format.xml  { render :xml => @color_scheme, :status => :created, :location => @color_scheme }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @color_scheme.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /color_schemes/1
  # PUT /color_schemes/1.xml
  def update
    @color_scheme = ColorScheme.find(params[:id])

    respond_to do |format|
      if @color_scheme.update_attributes(params[:color_scheme])
        flash[:notice] = tr("Saved color scheme", "controller/schemes")
        format.html { redirect_to(@color_scheme) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @color_scheme.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  def preview
    @color_scheme = ColorScheme.new(params[:color_scheme])
    respond_to do |format|    
      format.js {
        render(:partial => "color_schemes/scheme_css", :locals => {:scheme => @color_scheme })
      }
    end
  end  

  # DELETE /color_schemes/1
  # DELETE /color_schemes/1.xml
  def destroy
    @color_scheme = ColorScheme.find(params[:id])
    @color_scheme.destroy
    respond_to do |format|
      format.html { redirect_to(color_schemes_url) }
      format.xml  { head :ok }
    end
  end
end
