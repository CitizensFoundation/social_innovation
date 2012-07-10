class HomeController < ApplicationController

  caches_action :index,
                :if => proc {|c| c.do_action_cache? },
                :cache_path => proc {|c| c.action_cache_path},
                :expires_in => 5.minutes

  caches_action :world,
                :if => proc {|c| c.do_action_cache? },
                :cache_path => proc {|c| c.action_cache_path},
                :expires_in => 5.minutes

  caches_action :map,
                :cache_path => proc {|c| c.action_cache_path},
                :expires_in => 15.seconds

  def index
    @position_in_idea_name = true
    if current_instance.domain_name.include?("yrpri") and (not request.subdomains.any? or request.subdomains[0] == 'www')
      redirect_to :action=>"world"
    else
      @page_title = SubInstance.current.name
      @ideas = @new_ideas = Idea.published.newest.limit(3)
      @top_ideas = Idea.published.top_rank.limit(3).reject{|idea| @new_ideas.include?(idea)}
      @random_ideas = Idea.published.by_random.limit(3).reject{|idea| @new_ideas.include?(idea) or @top_ideas.include?(idea)}

      all_ideas = []
      all_ideas += @new_ideas if @new_ideas
      all_ideas += @top_ideas if @top_ideas
      all_ideas += @random_ideas if @random_ideas

      @endorsements = nil
      if logged_in? # pull all their endorsements on the ideas shown
        @endorsements = current_user.endorsements.active.find(:all, :conditions => ["idea_id in (?)", all_ideas.collect {|c| c.id}])
      end

      last = params[:last].blank? ? Time.now + 1.second : Time.parse(params[:last])
      @activities = Activity.active.top.feed(last).for_all_users.with_20
    end
  end

  def world
    if request.subdomains.any? and request.subdomains[0] != 'www'
      redirect_to "http://www.yrpri.org/home/world"
    else
      @position_in_idea_name = true
      @page_title = tr("{instance_name} Worldwide","shared/language_selection_master",:instance_name => tr(current_instance.name,"Name from database"))
      @ideas = @world_ideas = Idea.unscoped.where(:sub_instance_id=>SubInstance.find_by_short_name("united-nations").id).published.top_rank.limit(3)
      @eu_eea_ideas = Idea.unscoped.where(:sub_instance_id=>SubInstance.find_by_short_name("eu").id).published.top_rank.limit(3)
      @country_sub_instance = SubInstance.where(:iso_country_id=>@iso_country.id).first if @iso_country
      if @country_sub_instance
        @country_sub_instance_ideas = Idea.unscoped.where(:sub_instance_id=>@country_sub_instance.id).published.top_rank.limit(3)
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

  def map
    render :layout=>false, :content_type => 'application/xml'
  end

  def goto
    country = Tr8n::IsoCountry.find_by_country_english_name(params[:country_name])
    sub_instance = SubInstance.find_by_iso_country_id(country.id)
    redirect_to sub_instance.show_url
  end
end
