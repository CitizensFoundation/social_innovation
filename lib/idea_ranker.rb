class IdeaRanker
  @@all_ideas = Hash.new

  def perform
    puts "IdeaRanker.perform starting... at #{start_time=Time.now}"
    Instance.current = Instance.all.last
    setup_endorsements_counts
    if Instance.current.is_tags? and Tag.count > 0
      # update the # of issues people who've logged in the last two hours have up endorsed
      users = User.find_by_sql("SELECT users.id, users.up_issues_count, count(distinct taggings.tag_id) as num_issues
      FROM taggings,endorsements, users
      where taggings.taggable_id = endorsements.idea_id
      and taggings.taggable_type = 'Idea'
      and endorsements.user_id = users.id
      and endorsements.value > 0
      and endorsements.status = 'active'
      and (users.loggedin_at > '#{Time.now-2.hours}' or users.created_at > '#{Time.now-2.hours}')
      group by endorsements.user_id, users.id, users.up_issues_count")
      for u in users
        User.update_all("up_issues_count = #{u.num_issues}", "id = #{u.id}") unless u.up_issues_count == u.num_issues        
      end
      # update the # of issues they've DOWN endorsed
      users = User.find_by_sql("SELECT users.id, users.down_issues_count, count(distinct taggings.tag_id) as num_issues
      FROM taggings,endorsements, users
      where taggings.taggable_id = endorsements.idea_id
      and taggings.taggable_type = 'Idea'
      and endorsements.user_id = users.id
      and endorsements.value < 0
      and endorsements.status = 'active'
      and (users.loggedin_at > '#{Time.now-2.hours}' or users.created_at > '#{Time.now-2.hours}')
      group by endorsements.user_id, users.id, users.down_issues_count")
      for u in users
        User.update_all("down_issues_count = #{u.num_issues}", "id = #{u.id}") unless u.down_issues_count == u.num_issues
      end
    end

    # Delete all endorsements that do not have positions
    #Endorsement.delete_all("position IS NULL")

    # update the user's vote factor score
    users = User.active.all
    for u in users
      new_score = u.calculate_score
      if (u.score*100).to_i != (new_score*100).to_i
        u.update_attribute(:score,new_score) 
        for e in u.endorsements.active # their score changed, so now update all their endorsement scores
          current_score = e.score
          new_score = e.calculate_score
          e.update_attribute(:score, new_score) if new_score != current_score
        end
      end
    end

    # ranks all the ideas in the database with any endorsements.

    sub_instances_with_nil = SubInstance.all
    sub_instances_with_nil.each do |sub_instance|
      update_positions_by_sub_instance(sub_instance)
    end

    # determines any changes in the #1 idea for an issue, and updates the # of distinct endorsers and opposers across the entire issue
    
    if Instance.current.is_tags? and Tag.count > 0
      keep = []
      # get the number of endorsers on the issue
      tags = Tag.find_by_sql("SELECT tags.id, tags.name, tags.top_idea_id, tags.controversial_idea_id, tags.rising_idea_id, tags.official_idea_id, count(distinct endorsements.user_id) as num_endorsers
      FROM tags,taggings,endorsements
      where 
      taggings.taggable_id = endorsements.idea_id
      and taggable_type = 'Idea'
      and taggings.tag_id = tags.id
      and endorsements.status = 'active'
      and endorsements.value > 0
      group by tags.id, tags.name, tags.top_idea_id, tags.controversial_idea_id, tags.rising_idea_id, tags.official_idea_id, taggings.tag_id")
      for tag in tags
       keep << tag.id
       ideas = tag.ideas.published.top_rank # figure out the top idea while we're at it
       if ideas.any?
         if tag.top_idea_id != ideas[0].id # new top idea
           ActivityIssueIdea1.create(:tag => tag, :idea_id => ideas[0].id)
           tag.top_idea_id = ideas[0].id
         end
         controversial = tag.ideas.published.controversial
         if controversial.any? and tag.controversial_idea_id != controversial[0].id
           ActivityIssueIdeaControversial1.create(:tag => tag, :idea_id => controversial[0].id)
           tag.controversial_idea_id = controversial[0].id
         elsif controversial.empty?
           tag.controversial_idea_id = nil
         end
         rising = tag.ideas.published.rising
         if rising.any? and tag.rising_idea_id != rising[0].id
           ActivityIssueIdeaRising1.create(:tag => tag, :idea_id => rising[0].id)
           tag.rising_idea_id = rising[0].id
         elsif rising.empty?
           tag.rising_idea_id = nil
         end 
       else
         tag.top_idea_id = nil
         tag.controversial_idea_id = nil
         tag.rising_idea_id = nil
         tag.official_idea_id = nil
       end
       tag.up_endorsers_count = tag.num_endorsers
       tag.save(:validate => false)
      end
      # get the number of opposers on the issue
      tags = Tag.find_by_sql("SELECT tags.id, tags.name, tags.down_endorsers_count, count(distinct endorsements.user_id) as num_opposers
      FROM tags,taggings,endorsements
      where 
      taggings.taggable_id = endorsements.idea_id
      and taggable_type = 'Idea'
      and taggings.tag_id = tags.id
      and endorsements.status = 'active'
      and endorsements.value < 0
      group by tags.id, tags.name, tags.down_endorsers_count, taggings.tag_id")    
      for tag in tags
       keep << tag.id
       tag.update_attribute(:down_endorsers_count,tag.num_opposers) unless tag.down_endorsers_count == tag.num_opposers
      end
      if keep.any?
       Tag.connection.execute("update tags set up_endorsers_count = 0, down_endorsers_count = 0 where id not in (#{keep.uniq.compact.join(',')})")
      end
    end

    # now, check to see if the charts have been updated in the last day
    
    date = Time.now-4.hours-1.day
    previous_date = date-1.day
    start_date = date.year.to_s + "-" + date.month.to_s + "-" + date.day.to_s
    end_date = (date+1.day).year.to_s + "-" + (date+1.day).month.to_s + "-" + (date+1.day).day.to_s
    
    if IdeaChart.count(:conditions => ["date_year = ? and date_month = ? and date_day = ?", date.year, date.month, date.day]) == 0  # check to see if it's already been done for yesterday
      ideas = Idea.published.find(:all)
      for p in ideas
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
          previous = p.charts.find_by_date_year_and_date_month_and_date_day(previous_date.year,previous_date.month,previous_date.day) 
          if previous
            c.change = previous.position-c.position
            c.change_percent = (c.change.to_f/previous.position.to_f)          
          end
          c.save
          if p.created_at+2.days > Time.now # within last two days, check to see if we've given them their priroity debut activity
            ActivityIdeaDebut.create(:user => p.user, :idea => p, :position => p.position) unless ActivityIdeaDebut.find_by_idea_id(p.id)
          end        
        end
        Rails.cache.delete('views/idea_chart-' + p.id.to_s)
      end
      Rails.cache.delete('views/total_volume_chart') # reset the daily volume chart
      for u in User.active.at_least_one_endorsement.all
        u.index_24hr_change = u.index_change_percent(2)
        u.index_7days_change = u.index_change_percent(7)
        u.index_30days_change = u.index_change_percent(30)
        u.save(:validate => false)
        u.expire_charts
      end       
    end

    puts "IdeaRanker.perform before ranged positions... at #{Time.now} total of #{Time.now-start_time}"
    setup_ranged_endorsment_positions

    puts "IdeaRanker.perform stopping... at #{Time.now} total of #{Time.now-start_time}"
  end

  def setup_ranged_endorsment_positions
    sub_instances_with_nil = SubInstance.all<<nil
    sub_instances_with_nil.each do |sub_instance|
      setup_ranged_endorsment_position(sub_instance,Time.now-24.hours,"position_endorsed_24hr")
      setup_ranged_endorsment_position(sub_instance,Time.now-7.days,"position_endorsed_7days")
      setup_ranged_endorsment_position(sub_instance,Time.now-30.days,"position_endorsed_30days")
    end
  end
  
  private
  
  def update_positions_by_sub_instance(sub_instance)
    puts "update positions by sub_instances #{sub_instance}"
    if sub_instance
      SubInstance.current = sub_instance
      sub_instance_sql = "ideas.sub_instance_id = #{sub_instance.id}"
    else
      sub_instance_sql = "ideas.sub_instance_id IS NULL"
    end

    # make sure the scores for all the positions above the max position are set to 0
    Endorsement.update_all("score = 0", "position > #{Endorsement.max_position}")      
    # get the last version # for the different time lengths
    v = Ranking.filtered.find(:all, :select => "max(version) as version")[0]
    if v
     v = v.version || 0
     v+=1
    else
     v = 1
    end
    oldest = Ranking.filtered.find(:all, :select => "max(version) as version")[0].version
    v_1hr = oldest
    v_24hr = oldest
    r = Ranking.filtered.find(:all, :select => "max(version) as version", :conditions => "created_at < '#{Time.now-1.hour}'")[0]
    v_1hr = r.version if r
    r = Ranking.filtered.find(:all, :select => "max(version) as version", :conditions => "created_at < '#{Time.now-1.hour}'")[0]
    v_24hr = r.version if r

    ideas = Idea.find_by_sql("
       select ideas.id, ideas.endorsements_count, ideas.position_7days_change, ideas.up_endorsements_count, ideas.down_endorsements_count, \
       sum(((#{Endorsement.max_position+1}-endorsements.position)*endorsements.value)*users.score) as number
       from users,endorsements,ideas
       where endorsements.user_id = users.id
       and #{sub_instance_sql}
       and endorsements.idea_id = ideas.id
       and ideas.status = 'published'
       and endorsements.status = 'active' and endorsements.position <= #{Endorsement.max_position}
       group by ideas.id, ideas.endorsements_count, ideas.up_endorsements_count, ideas.down_endorsements_count, endorsements.idea_id
       order by number desc")

    i = 0
    puts "ideas.count = #{ideas.count}"
    for p in ideas
     puts "7D #{p.position_7days_change}"
     p.score = p.number
     first_time = false
     i = i + 1
     p.position = i
     puts "5D #{p.position_7days_change}"
     r = p.rankings.find_by_version(v_1hr)
     if r # it's in that version
       p.position_1hr = r.position
     else # not in that version, find the oldest one we can
       r = p.rankings.find(:all, :conditions => ["version < ?",v_1hr],:order => "version asc", :limit => 1)[0]
       if r
         p.position_1hr = r.position
       else # this is the first time they've been ranked
         p.position_1hr = p.position
         first_time = true
       end
     end
     puts "4D #{p.position_7days_change}"
     p.position_1hr_change = p.position_1hr - i 
     r = p.rankings.find_by_version(v_24hr)
     puts "3D #{p.position_7days_change}"
     if r # in that version
       p.position_24hr = r.position
       p.position_24hr_change = p.position_24hr - i          
     else # didn't exist yet, so let's find the oldest one we can
       r = p.rankings.find(:all, :conditions => ["version < ?",v_24hr],:order => "version asc", :limit => 1)[0]
       p.position_24hr = 0
       p.position_24hr_change = 0
     end   
     puts "2D #{p.position_7days_change}"
     date = Time.now-5.hours-7.days
     c = p.charts.find_by_date_year_and_date_month_and_date_day(date.year,date.month,date.day)
     if c
       puts "1D #{p.position_7days_change} #{c.position}"
       p.position_7days = c.position
       puts "position_7days_change #{p.position_7days_change} cc"
       p.position_7days_change = p.position_7days - i
       puts "position_7days_change #{p.position_7days_change} cc"
     else
       p.position_7days = 0
       puts "position_7days_change #{p.position_7days_change}"
       p.position_7days_change = 0
       puts "position_7days_change #{p.position_7days_change}"
     end

     date = Time.now-5.hours-30.days
     c = p.charts.find_by_date_year_and_date_month_and_date_day(date.year,date.month,date.day)
     if c
       p.position_30days = c.position
       p.position_30days_change = p.position_30days - i   
     else
       p.position_30days = 0
       p.position_30days_change = 0
     end      

     puts "#{0} #{p.position_7days_change} #{p.position}"
     p.trending_score = 0 #p.position_7days_change/p.position
     if p.down_endorsements_count == 0
       p.is_controversial = false
       p.controversial_score = 0
     else
       con = p.up_endorsements_count/p.down_endorsements_count
       if con > 0.5 and con < 2
         p.is_controversial = true
       else
         p.is_controversial = false
       end
       p.controversial_score = p.endorsements_count - (p.endorsements_count-p.down_endorsements_count).abs
     end
     # HACK Idea.update_all("position = #{p.position}, trending_score = #{p.trending_score}, is_controversial = #{p.is_controversial}, controversial_score = #{p.controversial_score}, score = #{p.score}, position_1hr = #{p.position_1hr}, position_1hr_change = #{p.position_1hr_change}, position_24hr = #{p.position_24hr}, position_24hr_change = #{p.position_24hr_change}, position_7days = #{p.position_7days}, position_7days_change = #{p.position_7days_change}, position_30days = #{p.position_30days}, position_30days_change = #{p.position_30days_change}", ["id = ?",p.id])
     Idea.update_all("position = #{p.position}, trending_score = #{p.trending_score}, is_controversial = #{p.is_controversial}, controversial_score = #{p.controversial_score}, score = #{p.score}, position_1hr = #{p.position_1hr}, position_24hr = #{p.position_24hr}, position_7days = #{p.position_7days}, position_30days = #{p.position_30days}", ["id = ?",p.id])
     r = Ranking.create(:version => v, :idea => p, :position => i, :endorsements_count => p.endorsements_count)
    end
    Idea.connection.execute("update ideas set position = 0, trending_score = 0, is_controversial = false, controversial_score = 0, score = 0 where endorsements_count = 0;")

    # check if there's a new fastest rising idea
    rising = Idea.filtered.published.rising.all[0]
    ActivityIdeaRising1.find_or_create_by_idea_id(rising.id) if rising
    SubInstance.current = nil
  end
  
  def setup_endorsements_counts
    Idea.all.each do |p|
      p.endorsements_count = p.endorsements.active_and_inactive.size
      p.up_endorsements_count = p.endorsements.endorsing.active_and_inactive.size
      p.down_endorsements_count = p.endorsements.opposing.active_and_inactive.size
      p.save(:validate => false)      
    end
  end

  def delete_duplicate_taggins_create_key(tagging)
    "#{tagging.tag_id}_#{tagging.taggable_id}_#{tagging.taggable_type}_#{tagging.context}"
  end

  def delete_duplicate_taggins
    old = {}
    deleted_count = 0
    Tagging.all.each do |t|
      if old[delete_duplicate_taggins_create_key(t)]
        deleted_count+=1
        t.destroy
      else
        old[delete_duplicate_taggins_create_key(t)]=t
      end
    end
    puts deleted_count
  end

  def add_missing_tags_for_ideas
    Idea.all.each do |p|
      if p.category
        the_tags = []
        the_tags<<p.category.name
        p.taggings.each do |tagging|
          if tagging.tag
            the_tags << tagging.tag.name
          else
            puts "NONONO #{tagging.tag_id}"
            tagging.destroy
          end
        end
        puts the_tags.uniq.join(",")
        p.issue_list = the_tags.uniq.join(",")
        puts "XXXX #{p.issue_list}"
        p.save
      else
        puts "MISSING CATEGORY: #{p.name}"
      end
    end
  end

  def setup_ranged_endorsment_position(sub_instance,time_since,position_db_name)
    puts "Processing #{position_db_name}"
    if sub_instance
      SubInstance.current = sub_instance
      sub_instance_sql = "ideas.sub_instance_id = #{sub_instance.id}"
    else
      sub_instance_sql = "ideas.sub_instance_id IS NULL"
    end
    @@all_ideas[sub_instance_sql] = Idea.find(:all, :conditions=>sub_instance_sql) unless @@all_ideas[sub_instance_sql]
    puts @@all_ideas[sub_instance_sql].count
    ideas = Idea.find_by_sql("
       select ideas.id, ideas.endorsements_count, ideas.up_endorsements_count, ideas.down_endorsements_count, \
       sum(((#{Endorsement.max_position+1}-endorsements.position)*endorsements.value)*users.score) as number
       from users,endorsements,ideas
       where endorsements.user_id = users.id
       and #{sub_instance_sql}
       and endorsements.idea_id = ideas.id
       and endorsements.created_at >= '#{time_since}'
       and ideas.status = 'published'
       and endorsements.status = 'active' and endorsements.position <= #{Endorsement.max_position}
       group by ideas.id, ideas.endorsements_count, ideas.up_endorsements_count, ideas.down_endorsements_count, endorsements.idea_id
       order by number desc")

    puts "Found #{ideas.count} in range"
    Idea.transaction do
      ideas.each_with_index do |idea,index|
        idea.reload
        eval_cmd = "idea.#{position_db_name} = #{index+1}"
        puts "#{idea.id} - #{eval_cmd}"
        eval eval_cmd
        idea.save
      end
    end

    not_in_range_ideas = @@all_ideas[sub_instance_sql]-ideas

    puts "Found #{not_in_range_ideas.count} NOT in range"
    Idea.transaction do
      not_in_range_ideas.each do |idea|
        idea.reload
        eval "idea.#{position_db_name} = nil"
        idea.save
      end
    end
    SubInstance.current = nil
  end  
end