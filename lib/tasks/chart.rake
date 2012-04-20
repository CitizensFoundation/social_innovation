namespace :chart do  
  
  desc "idea past update"
  task :past_ideas => :environment do
    Instance.current = Instance.all.last
    ideas = Idea.published.find(:all)
    for p in ideas
      date = p.created_at-4.hours-1.day
      previous = nil
      while date < Time.now
        date = date+1.day
        start_date = date.year.to_s + "-" + date.month.to_s + "-" + date.day.to_s
        end_date = (date+1.day).year.to_s + "-" + (date+1.day).month.to_s + "-" + (date+1.day).day.to_s
        # find the ranking
        r = p.rankings.find(:all, :conditions => ["rankings.created_at between ? and ?",start_date,end_date], :order => "created_at desc",:limit => 1)
        if r.any?
          c = p.charts.find_by_date_year_and_date_month_and_date_day(date.year,date.month,date.day)
          if not c
            c = IdeaChart.new(:idea => p, :date_year => date.year, :date_month => date.month, :date_day => date.day)
          end
          c.position = r[0].position
          c.up_count = p.endorsements.active.endorsing.count(:conditions => ["endorsements.created_at between ? and ?",start_date,end_date])
          c.down_count = p.endorsements.active.opposing.count(:conditions => ["endorsements.created_at between ? and ?",start_date,end_date])
          c.volume_count = c.up_count + c.down_count
          if previous
            c.change = previous.position-c.position
            c.change_percent = (c.change.to_f/previous.position.to_f)            
          end
          c.save
          previous = c
        end
      end
      Rails.cache.delete('views/idea_chart-' + p.id.to_s)
    end
  end  
  
  desc "idea past change update"
  task :past_idea_changes => :environment do
    Instance.current = Instance.all.last
    charts = IdeaChart.find(:all, :order => "idea_id")
    current = 0
    for chart in charts
      if current != chart.idea_id
        current = chart.idea_id
        previous = nil
      end
      if previous
        chart.change = previous.position-chart.position
        chart.change_percent = (chart.change.to_f/previous.position.to_f)
        chart.save(:validate => false)
      end
      previous = chart
    end
  end
  
  desc "user past update"
  task :past_users => :environment do
    Instance.current = Instance.all.last
    users = User.active.at_least_one_endorsement.by_ranking.all
    for p in users
      date = p.created_at-4.hours-1.day
      while date < Time.now
        date = date+1.day
        start_date = date.year.to_s + "-" + date.month.to_s + "-" + date.day.to_s
        end_date = (date+1.day).year.to_s + "-" + (date+1.day).month.to_s + "-" + (date+1.day).day.to_s
        # find the ranking
        r = p.rankings.find(:all, :conditions => ["user_rankings.created_at between ? and ?",start_date,end_date], :order => "created_at desc",:limit => 1)
        if r.any?
          c = p.charts.find_by_date_year_and_date_month_and_date_day(date.year,date.month,date.day)
          if not c
            c = UserChart.new(:user => p, :date_year => date.year, :date_month => date.month, :date_day => date.day)
          end
          c.position = r[0].position
          up_capitals = Capital.find(:all, :conditions => ["((recipient_id = ? and amount > 0) or (sender_id = ? and amount < 0)) and created_at between ? and ?", p.id, p.id, start_date, end_date])
          c.up_count = 0
          for cap in up_capitals
            c.up_count += cap.amount.abs
          end
          down_capitals = Capital.find(:all, :conditions => ["((recipient_id = ? and amount < 0) or (sender_id = ? and amount > 0)) and created_at between ? and ?", p.id, p.id, start_date, end_date])
          c.down_count = 0
          for cap in down_capitals
            c.down_count += cap.amount.abs
          end          
          c.volume_count = c.up_count + c.down_count
          c.save
        end
      end
      puts p.login
    end
  end      
  
  desc "daily user update"
  task :users => :environment do
    Instance.current = Instance.all.last
    date = Time.now-4.hours-1.day
    start_date = date.year.to_s + "-" + date.month.to_s + "-" + date.day.to_s
    end_date = (date+1.day).year.to_s + "-" + (date+1.day).month.to_s + "-" + (date+1.day).day.to_s
    users = User.active.at_least_one_endorsement.by_ranking.all
    for p in users
      # find the ranking
      r = p.rankings.find(:all, :conditions => ["user_rankings.created_at between ? and ?",start_date,end_date], :order => "created_at desc",:limit => 1)
      if r.any?
        c = p.charts.find_by_date_year_and_date_month_and_date_day(date.year,date.month,date.day)
        if not c
          c = UserChart.new(:user => p, :date_year => date.year, :date_month => date.month, :date_day => date.day)
        end
        c.position = r[0].position
        up_capitals = Capital.find(:all, :conditions => ["((recipient_id = ? and amount > 0) or (sender_id = ? and amount < 0)) and created_at between ? and ?", p.id, p.id, start_date, end_date])
        c.up_count = 0
        for cap in up_capitals
          c.up_count += cap.amount.abs
        end
        down_capitals = Capital.find(:all, :conditions => ["((recipient_id = ? and amount < 0) or (sender_id = ? and amount > 0)) and created_at between ? and ?", p.id, p.id, start_date, end_date])
        c.down_count = 0
        for cap in down_capitals
          c.down_count += cap.amount.abs
        end          
        c.volume_count = c.up_count + c.down_count
        c.save
        if p.created_at+2.days > Time.now # within last two days, check to see if we've given them their priroity debut activity
          ActivityUserRankingDebut.create(:user => p, :position => c.position) unless ActivityUserRankingDebut.find_by_user_id(p.id)
        end          
      end
    end
  end  
  
  desc "daily user update for branches"
  task :branch_users => :environment do
    Instance.current = Instance.all.last
    exit unless Instance.current.is_branches?
    for branch in Branch.all
      date = Time.now-4.hours-1.day
      start_date = date.year.to_s + "-" + date.month.to_s + "-" + date.day.to_s
      end_date = (date+1.day).year.to_s + "-" + (date+1.day).month.to_s + "-" + (date+1.day).day.to_s
      users = branch.users.active.at_least_one_endorsement.by_ranking.all
      for p in users
        # find the ranking
        r = branch.user_rankings.find(:all, :conditions => ["user_id = ? and branch_user_rankings.created_at between ? and ?",p.id, start_date,end_date], :order => "created_at desc",:limit => 1)
        if r.any?
          c = branch.user_charts.find_by_date_year_and_date_month_and_date_day_and_user_id(date.year,date.month,date.day,p.id)
          if not c
            c = branch.user_charts.new(:user => p, :date_year => date.year, :date_month => date.month, :date_day => date.day)
          end
          c.position = r[0].position
          c.save
        end
      end
    end
  end  
  
end