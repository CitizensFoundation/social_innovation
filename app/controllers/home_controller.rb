class HomeController < ApplicationController

  caches_action :index,
                :if => proc {|c| c.do_action_cache? },
                :cache_path => proc {|c| c.action_cache_path},
                :expires_in => 5.minutes

  def index
    @page_title = tr("Overview","home")
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
