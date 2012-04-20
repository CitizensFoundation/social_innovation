class HomeController < ApplicationController

  caches_action :index,
                :if => proc {|c| c.do_action_cache? },
                :cache_path => proc {|c| c.action_cache_path},
                :expires_in => 5.minutes
  
  layout "home"
  
  def top_issues
    @issues = Tag.most_ideas.all(:include => :top_idea, :limit => 10)
  end  
  
  def index
    @page_title = tr("{instance_name} Welcome","shared/language_selection_master",:instance_name => tr(current_instance.name,"Name from database"))
    @world_ideas = Idea.where(:sub_instance_id=>SubInstance.find_by_short_name("world").id).published.top_rank.limit(3)
    @eu_eea_ideas = Idea.where(:sub_instance_id=>SubInstance.find_by_short_name("eu").id).published.top_rank.limit(3)
    @country_sub_instance = SubInstance.where(:iso_country_id=>@iso_country.id).first if @iso_country
    if @country_sub_instance
      @country_sub_instance_ideas = Idea.where(:sub_instance_id=>@country_sub_instance.id).published.top_rank.limit(3)
    else
      @country_sub_instance_ideas = []
    end
    #@eu_eea_ideas = @country_sub_instance_ideas = @world_ideas = Idea.published.find(:all, :limit=>3, :order=>"rand()")
    
    all_ideas = []
    all_ideas += @country_sub_instance_ideas if @country_sub_instance_ideas
    all_ideas += @world_ideas if @world_ideas
    all_ideas += @eu_eea_ideas if @eu_eea_ideas
    
    @endorsements = nil
    if logged_in? # pull all their endorsements on the ideas shown
      @endorsements = current_user.endorsements.active.find(:all, :conditions => ["idea_id in (?)", all_ideas.collect {|c| c.id}])
    end

  end
end
