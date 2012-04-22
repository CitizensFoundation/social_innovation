class WidgetsController < ApplicationController
  
  def index
    @page_title = tr("Widgets for your blog or website", "controller/widgets", :instance_name => tr(current_instance.name,"Name from database"))
    respond_to do |format|
      format.html
    end
  end
  
  def ideas
    @page_title = tr("Put ideas on your website", "controller/widgets", :instance_name => tr(current_instance.name,"Name from database"))
    if logged_in?
      @widget = Widget.new(:controller_name => "ideas", :user => current_user, :action_name => "top")
    else
      @widget = Widget.new(:controller_name => "ideas", :action_name => "top")
    end
    respond_to do |format|
      format.html
    end    
  end
  
  def discussions
    @page_title = tr("Put discussions on your website", "controller/widgets", :instance_name => tr(current_instance.name,"Name from database"))
    if logged_in?
      @widget = Widget.new(:controller_name => "feed", :user => current_user, :action_name => "your_discussions")
    else
      @widget = Widget.new(:controller_name => "feed", :action_name => "discussions")
    end
    respond_to do |format|
      format.html
    end    
  end
  
  def preview
    @widget = Widget.new(params[:widget])
    respond_to do |format|    
      format.js {
        render :update do |page|
          page.replace_html 'widget_preview', render(:partial => "widgets/preview")
        end
      }
    end
  end
  
  def preview_iframe
    render :layout => false
  end
  
end
