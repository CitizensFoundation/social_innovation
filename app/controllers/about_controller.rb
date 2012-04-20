class AboutController < ApplicationController
  
  def index
    @page_title = tr("About {instance_name}", "controller/about", :instance_name => tr(current_instance.name,"Name from database"))
  end
  
  def show
    if params[:id] == 'privacy'
      @page_title = tr("{instance_name} Privacy Policy", "controller/about", :instance_name => tr(current_instance.name,"Name from database"))
      render :action => "privacy"
    elsif params[:id] == 'rules'
      @page_title = tr("{instance_name} Rules", "controller/about", :instance_name => tr(current_instance.name,"Name from database"))
      render :action => "rules"
    elsif params[:id] == 'faq'
      @page_title = tr("Answers to Frequently Asked Questions at {instance_name}", "controller/about", :instance_name => tr(current_instance.name,"Name from database"))
      render :action => "faq"
    elsif params[:id] == 'contributors'
      @page_title = tr("Contributors to {instance_name}", "controller/about", :instance_name => tr(current_instance.name,"Name from database"))
      render :action => "contributors"
    elsif params[:id] == 'council' and Instance.current.layout == "better_reykjavik"
      @page_title = tr("Reykjavik city council", "controller/council")
      render :action => 'council'
    elsif params[:id] == 'sub_instances'
      @page_title = tr("SubInstances", "controller/about")
      render :action => 'sub_instances'
    elsif params[:id] == 'sub_instance_rules'
      @page_title = tr("SubInstance rules", "controller/about")
      render :action => 'sub_instance_rules'
    elsif params[:id] == 'choose_sub_instance'
      @page_title = tr("Choose a sub_instance", "controller/about")
      render :action => 'choose_sub_instance'
    elsif params[:id] == 'sub_instance_what_kind'
      @page_title = tr("What kind of ideas", "controller/about")
      render :action => 'sub_instance_what_kind'
    elsif params[:id] == 'sub_instance_from_ideas_to_action'
      @page_title = tr("From ideas to action", "controller/about")
      render :action => 'sub_instance_from_ideas_to_action'
    elsif @page = Page.find_by_short_name(params[:id])
      @page_title = @page.name
    else
      render file: "/public/404.html", status: :not_found, layout: false
    end
  end
end
