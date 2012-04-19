class PriorityRanker
  @@all_priorities = Hash.new

  def perform
    puts "PriorityRanker.perform starting... at #{start_time=Time.now}"
    Instance.current = Instance.all.last
    setup_endorsements_counts
    if Instance.current.is_tags? and Tag.count > 0
      # update the # of issues people who've logged in the last two hours have up endorsed
      users = User.find_by_sql("SELECT users.id, users.up_issues_count, count(distinct taggings.tag_id) as num_issues
      FROM taggings,endorsements, users
      where taggings.taggable_id = endorsements.priority_id
      and taggings.taggable_type = 'Priority'
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
      where taggings.taggable_id = endorsements.priority_id
      and taggings.taggable_type = 'Priority'
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

    # ranks all the priorities in the database with any endorsements.

    sub_instances_with_nil = Partner.all<<nil
    sub_instances_with_nil.each do |sub_instance|
      update_positions_by_sub_instance(sub_instance)
    end

    # determines any changes in the #1 priority for an issue, and updates the # of distinct endorsers and opposers across the entire issue
    
    if Instance.current.is_tags? and Tag.count > 0
      keep = []
      # get the number of endorsers on the issue
      tags = Tag.find_by_sql("SELECT tags.id, tags.name, tags.top_priority_id, tags.controversial_priority_id, tags.rising_priority_id, tags.official_priority_id, count(distinct endorsements.user_id) as num_endorsers
      FROM tags,taggings,endorsements
      where 
      taggings.taggable_id = endorsements.priority_id
      and taggable_type = 'Priority'
      and taggings.tag_id = tags.id
      and endorsements.status = 'active'
      and endorsements.value > 0
      group by tags.id, tags.name, tags.top_priority_id, tags.controversial_priority_id, tags.rising_priority_id, tags.official_priority_id, taggings.tag_id")
      for tag in tags
       keep << tag.id
       priorities = tag.priorities.published.top_rank # figure out the top priority while we're at it
       if priorities.any?
         if tag.top_priority_id != priorities[0].id # new top priority
           ActivityIssuePriority1.create(:tag => tag, :priority_id => priorities[0].id)
           tag.top_priority_id = priorities[0].id
         end
         controversial = tag.priorities.published.controversial
         if controversial.any? and tag.controversial_priority_id != controversial[0].id
           ActivityIssuePriorityControversial1.create(:tag => tag, :priority_id => controversial[0].id)
           tag.controversial_priority_id = controversial[0].id
         elsif controversial.empty?
           tag.controversial_priority_id = nil
         end
         rising = tag.priorities.published.rising
         if rising.any? and tag.rising_priority_id != rising[0].id
           ActivityIssuePriorityRising1.create(:tag => tag, :priority_id => rising[0].id)
           tag.rising_priority_id = rising[0].id
         elsif rising.empty?
           tag.rising_priority_id = nil
         end 
       else
         tag.top_priority_id = nil
         tag.controversial_priority_id = nil
         tag.rising_priority_id = nil
         tag.official_priority_id = nil
       end
       tag.up_endorsers_count = tag.num_endorsers
       tag.save(:validate => false)
      end
      # get the number of opposers on the issue
      tags = Tag.find_by_sql("SELECT tags.id, tags.name, tags.down_endorsers_count, count(distinct endorsements.user_id) as num_opposers
      FROM tags,taggings,endorsements
      where 
      taggings.taggable_id = endorsements.priority_id
      and taggable_type = 'Priority'
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
    
    if PriorityChart.count(:conditions => ["date_year = ? and date_month = ? and date_day = ?", date.year, date.month, date.day]) == 0  # check to see if it's already been done for yesterday      
      priorities = Priority.published.find(:all)
      for p in priorities
        # find the ranking
        r = p.rankings.find(:all, :conditions => ["rankings.created_at between ? and ?",start_date,end_date], :order => "created_at desc",:limit => 1)
        if r.any?
          c = p.charts.find_by_date_year_and_date_month_and_date_day(date.year,date.month,date.day)
          if not c
            c = PriorityChart.new(:priority => p, :date_year => date.year, :date_month => date.month, :date_day => date.day)
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
            ActivityPriorityDebut.create(:user => p.user, :priority => p, :position => p.position) unless ActivityPriorityDebut.find_by_priority_id(p.id)
          end        
        end
        Rails.cache.delete('views/priority_chart-' + p.id.to_s)      
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

    puts "PriorityRanker.perform before ranged positions... at #{Time.now} total of #{Time.now-start_time}"    
    setup_ranged_endorsment_positions

    puts "PriorityRanker.perform stopping... at #{Time.now} total of #{Time.now-start_time}"
  end

  def setup_ranged_endorsment_positions
    sub_instances_with_nil = Partner.all<<nil
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
      Partner.current = sub_instance
      sub_instance_sql = "priorities.sub_instance_id = #{sub_instance.id}"
    else
      sub_instance_sql = "priorities.sub_instance_id IS NULL"
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

    priorities = Priority.find_by_sql("
       select priorities.id, priorities.endorsements_count, priorities.up_endorsements_count, priorities.down_endorsements_count, \
       sum(((#{Endorsement.max_position+1}-endorsements.position)*endorsements.value)*users.score) as number
       from users,endorsements,priorities
       where endorsements.user_id = users.id
       and #{sub_instance_sql}
       and endorsements.priority_id = priorities.id
       and priorities.status = 'published'
       and endorsements.status = 'active' and endorsements.position <= #{Endorsement.max_position}
       group by priorities.id, priorities.endorsements_count, priorities.up_endorsements_count, priorities.down_endorsements_count, endorsements.priority_id
       order by number desc")

    i = 0
    puts "priorities.count = #{priorities.count}"
    for p in priorities
     p.score = p.number
     first_time = false
     i = i + 1
     p.position = i

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

     p.position_1hr_change = p.position_1hr - i 
     r = p.rankings.find_by_version(v_24hr)
     if r # in that version
       p.position_24hr = r.position
       p.position_24hr_change = p.position_24hr - i          
     else # didn't exist yet, so let's find the oldest one we can
       r = p.rankings.find(:all, :conditions => ["version < ?",v_24hr],:order => "version asc", :limit => 1)[0]
       p.position_24hr = 0
       p.position_24hr_change = 0
     end   
 
     date = Time.now-5.hours-7.days
     c = p.charts.find_by_date_year_and_date_month_and_date_day(date.year,date.month,date.day)
     if c
       p.position_7days = c.position
       p.position_7days_change = p.position_7days - i   
     else
       p.position_7days = 0
       p.position_7days_change = 0
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
     
     p.trending_score = p.position_7days_change/p.position
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
     Priority.update_all("position = #{p.position}, trending_score = #{p.trending_score}, is_controversial = #{p.is_controversial}, controversial_score = #{p.controversial_score}, score = #{p.score}, position_1hr = #{p.position_1hr}, position_1hr_change = #{p.position_1hr_change}, position_24hr = #{p.position_24hr}, position_24hr_change = #{p.position_24hr_change}, position_7days = #{p.position_7days}, position_7days_change = #{p.position_7days_change}, position_30days = #{p.position_30days}, position_30days_change = #{p.position_30days_change}", ["id = ?",p.id])
     r = Ranking.create(:version => v, :priority => p, :position => i, :endorsements_count => p.endorsements_count)
    end
    Priority.connection.execute("update priorities set position = 0, trending_score = 0, is_controversial = false, controversial_score = 0, score = 0 where endorsements_count = 0;")

    # check if there's a new fastest rising priority
    rising = Priority.filtered.published.rising.all[0]
    ActivityPriorityRising1.find_or_create_by_priority_id(rising.id) if rising    
    Partner.current = nil
  end
  
  def setup_endorsements_counts
    Priority.all.each do |p|
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

  def add_missing_tags_for_priorities
    Priority.all.each do |p|
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
      Partner.current = sub_instance
      sub_instance_sql = "priorities.sub_instance_id = #{sub_instance.id}"
    else
      sub_instance_sql = "priorities.sub_instance_id IS NULL"
    end
    @@all_priorities[sub_instance_sql] = Priority.find(:all, :conditions=>sub_instance_sql) unless @@all_priorities[sub_instance_sql]
    puts @@all_priorities[sub_instance_sql].count
    priorities = Priority.find_by_sql("
       select priorities.id, priorities.endorsements_count, priorities.up_endorsements_count, priorities.down_endorsements_count, \
       sum(((#{Endorsement.max_position+1}-endorsements.position)*endorsements.value)*users.score) as number
       from users,endorsements,priorities
       where endorsements.user_id = users.id
       and #{sub_instance_sql}
       and endorsements.priority_id = priorities.id
       and endorsements.created_at >= '#{time_since}'
       and priorities.status = 'published'
       and endorsements.status = 'active' and endorsements.position <= #{Endorsement.max_position}
       group by priorities.id, priorities.endorsements_count, priorities.up_endorsements_count, priorities.down_endorsements_count, endorsements.priority_id
       order by number desc")

    puts "Found #{priorities.count} in range"
    Priority.transaction do
      priorities.each_with_index do |priority,index|
        priority.reload
        eval_cmd = "priority.#{position_db_name} = #{index+1}"
        puts "#{priority.id} - #{eval_cmd}"
        eval eval_cmd
        priority.save
      end
    end

    not_in_range_priorites = @@all_priorities[sub_instance_sql]-priorities

    puts "Found #{not_in_range_priorites.count} NOT in range"
    Priority.transaction do
      not_in_range_priorites.each do |priority|
        priority.reload
        eval "priority.#{position_db_name} = nil"
        priority.save
      end
    end
    Partner.current = nil
  end  
end