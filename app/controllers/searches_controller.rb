class SearchesController < ApplicationController
  
  def index
    Rails.logger.info("Category Name #{params[:category_name]} CRC #{params[:category_name].to_crc32}") if params[:cached_issue_list]
    @page_title = tr("Search {instance_name} ideas", "controller/searches", :instance_name => tr(current_instance.name,"Name from database"))
    if params[:q]
      @query = params[:q]
      @page_title = tr("Search for '{query}'", "controller/searches", :instance_name => tr(current_instance.name,"Name from database"), :query => @query)
      @facets = ThinkingSphinx.facets @query, :all_facets => true, :with => {:sub_instance_id => SubInstance.current ? SubInstance.current.id : 0}, :star => true, :page => params[:page]
      if params[:category_name]
        @search_results = @facets.for(:category_name=>params[:category_name])
      elsif params[:class]
        @search_results = @facets.for(:class=>params[:class].to_s)
      else
        @search_results = ThinkingSphinx.search @query, :with => {:sub_instance_id => SubInstance.current ? SubInstance.current.id : 0}, :star => true, :retry_stale => true, :page => params[:page]
      end
    end
    respond_to do |format|
      format.html
      format.xml { render :xml => @ideas.to_xml(:except => [:user_agent,:ip_address,:referrer]) }
      format.json { render :json => @ideas.to_json(:except => [:user_agent,:ip_address,:referrer]) }
    end
  end
end
