class SearchesController < ApplicationController
  
  def index
    Rails.logger.info("Category Name #{params[:category_name]} CRC #{params[:category_name].to_crc32}") if params[:cached_issue_list]
    @page_title = tr("Search {instance_name} ideas", "controller/searches", :instance_name => tr(current_instance.name,"Name from database"))
    if params[:q]
      @query = params[:q]
      @page_title = tr("Search for '{query}'", "controller/searches", :instance_name => tr(current_instance.name,"Name from database"), :query => @query)
      if params[:global]
        @facets = ThinkingSphinx.facets @query, :all_facets => true, :star => true, :page => params[:page]
      else
        @facets = ThinkingSphinx.facets @query, :all_facets => true, :with => {:sub_instance_id => SubInstance.current ? SubInstance.current.id : 0}, :star => true, :page => params[:page]
      end
      if params[:category_name]
        @search_results = @facets.for(:category_name=>params[:category_name])
      elsif params[:class]
        @search_results = @facets.for(:class=>params[:class].to_s)
      else
        if params[:global]
          @search_results = ThinkingSphinx.search @query, :order => :updated_at_sort, :sort_mode => :desc, :star => true, :retry_stale => true, :page => params[:page]
        else
          @search_results = ThinkingSphinx.search @query, :order => :updated_at_sort, :sort_mode => :desc, :with => {:sub_instance_id => SubInstance.current.id }, :star => true, :retry_stale => true, :page => params[:page]
        end
      end
    end
    respond_to do |format|
      format.html
      format.xml { render :xml => @ideas.to_xml(:except => [:user_agent,:ip_address,:referrer]) }
      format.json { render :json => @ideas.to_json(:except => [:user_agent,:ip_address,:referrer]) }
    end
  end

  #TODO: We need a new method here for handling the search
end
