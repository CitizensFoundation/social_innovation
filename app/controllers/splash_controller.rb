class SplashController < ApplicationController

  def index
    @page_title = tr("Watch what people are doing at {instance_name}", "controller/splash", :instance_name => tr(current_instance.name,"Name from database"))
    if User.adapter == 'postgresql'
      @priorities = Priority.find :all, :conditions => "status='published' and position > 0 and endorsements_count > 2", :order => "RANDOM()", :limit => 200
    else
      @priorities = Priority.find :all, :conditions => "status='published' and position > 0 and endorsements_count > 2", :order => "rand()", :limit => 200
    end
  end  
  
end
