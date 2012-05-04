
class Helper
  include Singleton
  include ActionView::Helpers::SanitizeHelper
end

def self.help
  Helper.instance
end

def remove_all_endorsements_except
  # 15436
  # 2818
  # 18254

  ids = [14,10,3,60,99,14,108,56,22,10,28,25,55,121,99,7,68,113,135].uniq
  # Check if any endorsements in ids
  total = 0
  ids.each.each do |id|
    puts total+=Endorsement.find_all_by_idea_id(id).count
  end
  puts total
  Endorsement.delete_all(["endorsements.idea_id NOT IN (?)",ids])
  Endorsement.all.each_with_index do |e,i|
    puts i
    e.status = "finished"
    e.position = nil
    e.save
  end
end

namespace :fix do

  desc "Update idea change logs"
  task :update_change_logs => :environment do
    IdeaStatusChangeLog.transaction do
      IdeaStatusChangeLog.all.each do |status|
        new_subject = help.strip_tags(status.content)
        if new_subject.empty?
          status.destroy
        else
          status.subject = new_subject
          status.content = nil
          status.date = status.updated_at
          status.save
        end
      end
    end
  end

  desc "tweak videos"
  task :tweak_videos => :environment do
    ProcessSpeechMasterVideo.all.each do |m|
      if m.id<9
        m.published = true
        m.in_processing = false
        m.save
      elsif m.id<11
        m.published = false
        m.in_processing = true
        m.save
      end
    end
    ProcessSpeechVideo.all.each do |m|
      if m.id<281
        m.published = true
        m.in_processing = false
        m.save
      end
    end
  end

  desc "reset process documents"
  task :reset_process_documents => :environment do
    connection = ActiveRecord::Base.connection();
    connection.execute("DELETE FROM process_documents;")
    connection.execute("DELETE FROM process_document_elements;")
  end

  desc "reset database"
  task :reset_database_YES => :environment do
    puts "1"
    connection = ActiveRecord::Base.connection();
    connection.execute("DELETE FROM activities;")
    connection.execute("DELETE FROM ads;")
    connection.execute("DELETE FROM blasts;")
    connection.execute("DELETE FROM capitals;")
    connection.execute("DELETE FROM changes;")
    connection.execute("DELETE FROM client_applications;")
    connection.execute("DELETE FROM categories;")
    connection.execute("DELETE FROM generated_proposal_elements;")
    connection.execute("DELETE FROM generated_proposals;")
    connection.execute("DELETE FROM comments;")
    #connection.execute("DELETE FROM constituents;")
    connection.execute("DELETE FROM delayed_jobs;")
    connection.execute("DELETE FROM document_qualities;")
    connection.execute("DELETE FROM document_revisions;")
    connection.execute("DELETE FROM documents;")
    connection.execute("DELETE FROM endorsements;")
    puts "2"
    connection.execute("DELETE FROM facebook_templates;")
    connection.execute("DELETE FROM feeds;")
    connection.execute("DELETE FROM following_discussions;")
    connection.execute("DELETE FROM followings;")
    connection.execute("DELETE FROM legislators;")
    connection.execute("DELETE FROM letters;")
    connection.execute("DELETE FROM messages;")
    connection.execute("DELETE FROM notifications;")
    connection.execute("DELETE FROM pages;")
    connection.execute("DELETE FROM sub_instances;")
    connection.execute("DELETE FROM pictures;")
    connection.execute("DELETE FROM point_qualities;")
    connection.execute("DELETE FROM points;")
    connection.execute("DELETE FROM ideas;")
    connection.execute("DELETE FROM idea_charts;")
    puts "3"
    connection.execute("DELETE FROM idea_status_change_logs;")
    connection.execute("DELETE FROM process_discussions;")
    connection.execute("DELETE FROM process_document_elements;")
    connection.execute("DELETE FROM process_document_states;")
    connection.execute("DELETE FROM process_document_types;")
    connection.execute("DELETE FROM process_documents;")
    connection.execute("DELETE FROM process_speech_master_videos;")
    connection.execute("DELETE FROM process_speech_videos;")
    connection.execute("DELETE FROM process_types;")
    connection.execute("DELETE FROM profiles;")
    connection.execute("DELETE FROM rankings;")
    connection.execute("DELETE FROM ratings;")
    puts "4"
    connection.execute("DELETE FROM relationships;")
    connection.execute("DELETE FROM revisions;")
    connection.execute("DELETE FROM shown_ads;")
    connection.execute("DELETE FROM signups;")
    connection.execute("DELETE FROM tag_subscriptions;")
    connection.execute("DELETE FROM taggings;")
    connection.execute("DELETE FROM tags;")
    connection.execute("DELETE FROM unsubscribes;")
    connection.execute("DELETE FROM user_charts;")
    connection.execute("DELETE FROM user_contacts;")
    connection.execute("DELETE FROM user_rankings;")
    connection.execute("DELETE FROM users WHERE id != 1;")
    connection.execute("DELETE FROM votes;")
    connection.execute("DELETE FROM webpages;")
    puts "5"

    connection.execute("OPTIMIZE TABLE activities;")
    connection.execute("OPTIMIZE TABLE ads;")
    connection.execute("OPTIMIZE TABLE blasts;")
    connection.execute("OPTIMIZE TABLE capitals;")
    connection.execute("OPTIMIZE TABLE changes;")
    connection.execute("OPTIMIZE TABLE comments;")
    #connection.execute("OPTIMIZE TABLE constituents;")
    connection.execute("OPTIMIZE TABLE delayed_jobs;")
    connection.execute("OPTIMIZE TABLE document_qualities;")
    connection.execute("OPTIMIZE TABLE document_revisions;")
    puts "6"
    connection.execute("OPTIMIZE TABLE documents;")
    connection.execute("OPTIMIZE TABLE endorsements;")
    connection.execute("OPTIMIZE TABLE facebook_templates;")
    connection.execute("OPTIMIZE TABLE feeds;")
    connection.execute("OPTIMIZE TABLE following_discussions;")
    connection.execute("OPTIMIZE TABLE followings;")
    connection.execute("OPTIMIZE TABLE legislators;")
    connection.execute("OPTIMIZE TABLE letters;")
    connection.execute("OPTIMIZE TABLE messages;")
    connection.execute("OPTIMIZE TABLE notifications;")
    connection.execute("OPTIMIZE TABLE pages;")
    connection.execute("OPTIMIZE TABLE sub_instances;")
    connection.execute("OPTIMIZE TABLE pictures;")
    connection.execute("OPTIMIZE TABLE point_qualities;")
    puts "7"
    connection.execute("OPTIMIZE TABLE points;")
    connection.execute("OPTIMIZE TABLE ideas;")
    connection.execute("OPTIMIZE TABLE idea_charts;")
    connection.execute("OPTIMIZE TABLE idea_status_change_logs;")
    connection.execute("OPTIMIZE TABLE process_types;")
    puts "8"
    connection.execute("OPTIMIZE TABLE profiles;")
    connection.execute("OPTIMIZE TABLE rankings;")
    connection.execute("OPTIMIZE TABLE ratings;")
    connection.execute("OPTIMIZE TABLE relationships;")
    connection.execute("OPTIMIZE TABLE revisions;")
    connection.execute("OPTIMIZE TABLE shown_ads;")
    connection.execute("OPTIMIZE TABLE signups;")
    connection.execute("OPTIMIZE TABLE tag_subscriptions;")
    connection.execute("OPTIMIZE TABLE taggings;")
    connection.execute("OPTIMIZE TABLE tags;")
    puts "9"
    connection.execute("OPTIMIZE TABLE unsubscribes;")
    connection.execute("OPTIMIZE TABLE user_charts;")
    connection.execute("OPTIMIZE TABLE user_contacts;")
    connection.execute("OPTIMIZE TABLE user_rankings;")
    puts "10"
    connection.execute("OPTIMIZE TABLE users;")
    connection.execute("OPTIMIZE TABLE votes;")
    connection.execute("OPTIMIZE TABLE webpages;")
    puts "11"
      #categories
      #color_schemes
      #instances
      #portlet_containers
      #portlet_positions
      #portlet_template_categories
      #portlet_templates
      #portlets
      #schema_migrations
      #simple_captcha_data
      #widgets

    u=User.first
    u.endorsements_count = 0
    u.up_endorsements_count = 0
    u.down_endorsements_count = 0
    u.up_issues_count = 0
    u.down_issues_count = 0
    u.comments_count = 0
    u.score = 0.1
    u.capitals_count = 0
    u.twitter_count = 0
    u.followers_count = 0
    u.followings_count = 0
    u.ignorers_count = 0
    u.ignorings_count = 0
    u.position_24hr = 0
    u.position_7days = 0
    u.position_30days = 0
    u.position_24hr_delta = 0
    u.position_7days_delta = 0
    u.position_30days_delta = 0
    u.position = 0
    u.ads_count = 0
    u.changes_count = 0
    u.top_endorsement_id = nil
    u.contacts_count = 0
    u.contacts_members_count = 0
    u.contacts_invited_count = 0
    u.contacts_not_invited_count = 0
    u.documents_count = 0
    u.document_revisions_count = 0
    u.points_count = 0
    u.index_24hr_delta = 0.0
    u.index_7days_delta = 0.0
    u.index_30days_delta = 0.0
    u.received_notifications_count = 0
    u.unread_notifications_count = 0
    u.point_revisions_count = 0
    u.qualities_count = 0
    #u.constituents_count = 0
    u.warnings_count = 0
    u.referrals_count = 0
    u.imported_contacts_count = 0
    u.save(false)
    if Instance.last.default_tags_checkbox
      Instance.last.default_tags_checkbox.split(",").each do |t|
        tag=Tag.new
        tag.name = t
        tag.save
      end
    end
  end

  desc "delete activities that don't have objects which are now nil"
  task :abandoned_activities => :environment do
    # not sure if this works yet
    activities = Activity.find_by_sql("SELECT * from activities where NOT EXISTS (select * from users where activities.other_user_id = users.id or activities.other_user_id is null)")
  end
  
  desc "fix default branches for users"
  task :default_branch => :environment do
    Instance.all.last.update_user_default_branch
  end
  
  desc "fix endorsement counts"
  task :endorsement_counts => :environment do
    Instance.current = Instance.all.last
    for p in Idea.find(:all)
      p.endorsements_count = p.endorsements.active_and_inactive.size
      p.up_endorsements_count = p.endorsements.endorsing.active_and_inactive.size
      p.down_endorsements_count = p.endorsements.opposing.active_and_inactive.size
      p.save(:validate => false)      
    end
  end
  
  desc "fix endorsement positions"
  task :endorsement_positions => :environment do
    Instance.current = Instance.all.last
    for u in User.active.at_least_one_endorsement.all(:order => "users.id asc")
      row = 0
      for e in u.endorsements.active.by_position
        row += 1
        e.update_attribute(:position,row) unless e.position == row
        u.update_attribute(:top_endorsement_id,e.id) if u.top_endorsement_id != e.id and row == 1
      end
      puts u.login
    end
  end
  
  desc "fix endorsement scores"
  task :endorsement_scores => :environment do
    Instance.current = Instance.all.last
    Endorsement.active.find_in_batches(:include => :user) do |endorsement_group|
      for e in endorsement_group
        current_score = e.score
        new_score = e.calculate_score
        e.update_attribute(:score, new_score) if new_score != current_score
      end
    end      
  end
  
  desc "fix duplicate endorsements"
  task :duplicate_endorsements => :environment do
    Instance.current = Instance.all.last
    # get users with duplicate endorsements
    endorsements = Endorsement.find_by_sql("
        select user_id, idea_id, count(*) as num_times
        from endorsements
        group by user_id,idea_id
  	    having count(*) > 1
    ")
    for e in endorsements
      user = e.user
      idea = e.idea
      multiple_endorsements = user.endorsements.active.find(:all, :conditions => ["idea_id = ?",idea.id], :order => "endorsements.position")
      if multiple_endorsements.length > 1
        for c in 1..multiple_endorsements.length-1
          multiple_endorsements[c].destroy
        end
      end
    end
  end  
  
  desc "fix duplicate top idea activities"
  task :duplicate_idea1_activities => :environment do
    Instance.current = Instance.all.last
    models = [ActivityIdea1,ActivityIdea1Opposed]
    for model in models
      dupes = Activity.find_by_sql("select user_id, idea_id, count(*) as number from activities
      where type = '#{model}'
      group by user_id, idea_id
      order by count(*) desc")
      for a in dupes
        if a.number.to_i > 1
          activities = model.find(:all, :conditions => ["user_id = ? and idea_id = ?",a.user_id,a.idea_id], :order => "changed_at desc")
          for c in 1..activities.length-1
            activities[c].destroy
          end
        end
      end
    end
  end
  
  desc "fix discussion counts"
  task :discussion_counts => :environment do
    Instance.current = Instance.all.last
    ideas = Idea.find(:all)
    for p in ideas
      p.update_attribute(:discussions_count,p.activities.discussions.for_all_users.active.size) if p.activities.discussions.for_all_users.active.size != p.discussions_count
    end
    points = Point.find(:all)
    for p in points
      p.update_attribute(:discussions_count,p.activities.discussions.for_all_users.active.size) if p.activities.discussions.for_all_users.active.size != p.discussions_count
    end
    docs = Document.find(:all)
    for d in docs
      d.update_attribute(:discussions_count, d.activities.discussions.for_all_users.active.size) if d.activities.discussions.for_all_users.active.size != d.discussions_count
    end
  end
  
  desc "fix tag counts"
  task :tag_counts => :environment do
    Instance.current = Instance.all.last
    for t in Tag.all
      t.update_counts
      t.save(:validate => false)
    end
  end  
  
  desc "fix branch counts"
  task :branch_counts => :environment do
    Instance.current = Instance.all.last
    for b in Branch.all
      b.update_counts
      b.save(:validate => false)
    end
    Branch.expire_cache
  end  

  desc "fix comment participant dupes"
  task :comment_participants => :environment do
    Instance.current = Instance.all.last
    Activity.record_timestamps = false
    user_id = nil
    activity_id = nil
    for ac in ActivityCommentParticipant.active.find(:all, :order => "activity_id asc, user_id asc")
      if activity_id == ac.activity_id and user_id == ac.user_id
        ac.destroy
      else
        activity_id = ac.activity_id
        user_id = ac.user_id
        ac.update_attribute(:comments_count,ac.activity.comments.published.count(:conditions => ["user_id = ?",user_id]))
      end
    end
    Activity.record_timestamps = true
  end
  
  desc "fix helpful counts"
  task :helpful_counts => :environment do
    Instance.current = Instance.all.last
    endorser_helpful_points = Point.find_by_sql("SELECT points.id, points.endorser_helpful_count, count(*) as number
    FROM points INNER JOIN endorsements ON points.idea_id = endorsements.idea_id
    	 INNER JOIN point_qualities ON point_qualities.user_id = endorsements.user_id AND point_qualities.point_id = points.id
    where endorsements.value  =1
    and point_qualities.value = true
    group by points.id, points.endorser_helpful_count
    having number <> endorser_helpful_count")
    for point in endorser_helpful_points
      point.update_attribute("endorser_helpful_count",point.number)
    end

    endorser_helpful_points = Document.find_by_sql("SELECT documents.id, documents.endorser_helpful_count, count(*) as number
    FROM documents INNER JOIN endorsements ON documents.idea_id = endorsements.idea_id
    	 INNER JOIN document_qualities ON document_qualities.user_id = endorsements.user_id AND document_qualities.document_id = documents.id
    where endorsements.value  =1
    and document_qualities.value = 1
    group by documents.id, documents.endorser_helpful_count
    having number <> endorser_helpful_count")
    for doc in endorser_helpful_points
      doc.update_attribute("endorser_helpful_count",doc.number)
    end    

    opposer_helpful_points = Point.find_by_sql("SELECT points.id, points.opposer_helpful_count, count(*) as number
    FROM points INNER JOIN endorsements ON points.idea_id = endorsements.idea_id
    	 INNER JOIN point_qualities ON point_qualities.user_id = endorsements.user_id AND point_qualities.point_id = points.id
    where endorsements.value = -1
    and point_qualities.value = true
    group by points.id, points.opposer_helpful_count
    having number <> opposer_helpful_count")
    for point in opposer_helpful_points
      point.update_attribute("opposer_helpful_count",point.number)
    end  

    opposer_helpful_points = Document.find_by_sql("SELECT documents.id, documents.opposer_helpful_count, count(*) as number
    FROM documents INNER JOIN endorsements ON documents.idea_id = endorsements.idea_id
    	 INNER JOIN document_qualities ON document_qualities.user_id = endorsements.user_id AND document_qualities.document_id = documents.id
    where endorsements.value = -1
    and document_qualities.value = 1
    group by documents.id, documents.opposer_helpful_count
    having number <> opposer_helpful_count")
    for doc in opposer_helpful_points
      doc.update_attribute("opposer_helpful_count",doc.number)
    end    

    endorser_unhelpful_points = Point.find_by_sql("SELECT points.id, points.endorser_unhelpful_count, count(*) as number
    FROM points INNER JOIN endorsements ON points.idea_id = endorsements.idea_id
    	 INNER JOIN point_qualities ON point_qualities.user_id = endorsements.user_id AND point_qualities.point_id = points.id
    where endorsements.value = 1
    and point_qualities.value = false
    group by points.id, points.endorser_unhelpful_count
    having number <> endorser_unhelpful_count")
    for point in endorser_unhelpful_points
      point.update_attribute("endorser_unhelpful_count",point.number)
    end  

    endorser_unhelpful_points = Document.find_by_sql("SELECT documents.id, documents.endorser_unhelpful_count, count(*) as number
    FROM documents INNER JOIN endorsements ON documents.idea_id = endorsements.idea_id
    	 INNER JOIN document_qualities ON document_qualities.user_id = endorsements.user_id AND document_qualities.document_id = documents.id
    where endorsements.value  =1
    and document_qualities.value = 0
    group by documents.id, documents.endorser_unhelpful_count
    having number <> endorser_unhelpful_count")
    for doc in endorser_unhelpful_points
      doc.update_attribute("endorser_unhelpful_count",doc.number)
    end    

    opposer_unhelpful_points = Point.find_by_sql("SELECT points.id, points.opposer_unhelpful_count, count(*) as number
    FROM points INNER JOIN endorsements ON points.idea_id = endorsements.idea_id
    	 INNER JOIN point_qualities ON point_qualities.user_id = endorsements.user_id AND point_qualities.point_id = points.id
    where endorsements.value = -1
    and point_qualities.value = false
    group by points.id, points.opposer_unhelpful_count
    having number <> opposer_unhelpful_count")
    for point in opposer_unhelpful_points
      point.update_attribute("opposer_unhelpful_count",point.number)
    end      

    opposer_unhelpful_points = Document.find_by_sql("SELECT documents.id, documents.opposer_unhelpful_count, count(*) as number
    FROM documents INNER JOIN endorsements ON documents.idea_id = endorsements.idea_id
    	 INNER JOIN document_qualities ON document_qualities.user_id = endorsements.user_id AND document_qualities.document_id = documents.id
    where endorsements.value = -1
    and document_qualities.value = 0
    group by documents.id, documents.opposer_unhelpful_count
    having number <> opposer_unhelpful_count")
    for doc in opposer_unhelpful_points
      doc.update_attribute("opposer_unhelpful_count",doc.number)
    end  

    #neutral counts
    Point.connection.execute("update points
    set neutral_unhelpful_count = unhelpful_count - endorser_unhelpful_count - opposer_unhelpful_count,
    neutral_helpful_count =  helpful_count - endorser_helpful_count - opposer_helpful_count")
    Document.connection.execute("update documents
    set neutral_unhelpful_count = unhelpful_count - endorser_unhelpful_count - opposer_unhelpful_count,
    neutral_helpful_count =  helpful_count - endorser_helpful_count - opposer_helpful_count")           
  end  
  
  desc "fix user counts"
  task :user_counts => :environment do
    Instance.current = Instance.all.last
    users = User.find(:all)
    for u in users
      u.update_counts
      u.save(:validate => false)
    end
  end
  
  desc "update official_status on ideas"
  task :official_status => :environment do
    Instance.current = Instance.all.last
    if Instance.current.has_official?
      Idea.connection.execute("update ideas set official_value = 1
      where official_value <> 1 and id in (select idea_id from endorsements where user_id = #{govt.official_user_id} and value > 0 and status = 'active')")
      Idea.connection.execute("update ideas set official_value = -1
      where official_value <> -1 and id in (select idea_id from endorsements where user_id = #{govt.official_user_id} and value < 0 and status = 'active')")
      Idea.connection.execute("update ideas set official_value = 0
      where official_value <> 0 and id not in (select idea_id from endorsements where user_id = #{govt.official_user_id} and status = 'active')")
    end
  end  
  
  desc "re-process doc & point diffs"
  task :diffs => :environment do
    Instance.current = Instance.all.last
    models = [Document,Point]
    for model in models
      for p in model.all
        revisions = p.revisions.by_recently_created
        puts p.name
        for row in 0..revisions.length-1
          if row == revisions.length-1
            revisions[row].content_diff = revisions[row].content
          else
            revisions[row].content_diff = HTMLDiff.diff(revisions[row+1].content,revisions[row].content)
          end
          revisions[row].save(:validate => false)
        end
      end
    end
  end
  
  desc "run the auto_html processing on all objects. used in case of changes to auto_html filtering rules"
  task :content_html => :environment do
    Instance.current = Instance.all.last
    models = [Comment,Message,Point,Revision,Document,DocumentRevision]
    for model in models
      for p in model.all
        p.auto_html_prepare
        p.update_attribute(:content_html, p.content_html)
      end
    end
  end
  
  desc "this will fix the activity changed_ats"
  task :activities_changed_at => :environment do
    Instance.current = Instance.all.last
    Activity.connection.execute("UPDATE activities set changed_at = created_at")
    for a in Activity.active.discussions.all
      if a.comments.published.size > 0
        a.update_attribute(:changed_at, a.comments.published.by_recently_created.first.created_at)
      end
    end
  end  
  
  desc "make all commenters on a discussion follow that discussion, this should only be done once"
  task :discussion_followers => :environment do
    Instance.current = Instance.all.last
    for a in Activity.discussions.active.all
      for u in a.commenters
        a.followings.find_or_create_by_user_id(u.id)
      end
      a.followings.find_or_create_by_user_id(a.user_id) # add the owner of the activity too
    end
    Activity.connection.execute("DELETE FROM activities where type = 'ActivityDiscussionFollowingNew'")
  end
  
  desc "branch endorsements"
  task :branch_endorsements => :environment do
    Instance.current = Instance.all.last
    for branch in Branch.all
      endorsement_scores = Endorsement.active.find(:all, 
        :select => "endorsements.idea_id, sum((#{Endorsement.max_position+1}-endorsements.position)*endorsements.value) as score, count(*) as endorsements_number",
        :joins => "endorsements INNER JOIN ideas ON ideas.id = endorsements.idea_id",
        :conditions => ["endorsements.user_id in (?) and endorsements.position <= #{Endorsement.max_position}",branch.user_ids], 
        :group => "endorsements.idea_id",
        :order => "score desc")
      down_endorsement_counts = Endorsement.active.find(:all, 
        :select => "endorsements.idea_id, count(*) as endorsements_number",
        :joins => "endorsements INNER JOIN ideas ON ideas.id = endorsements.idea_id",
        :conditions => ["endorsements.value = -1 and endorsements.user_id in (?)",branch.user_ids], 
        :group => "endorsements.idea_id")
      up_endorsement_counts = Endorsement.active.find(:all, 
        :select => "endorsements.idea_id, count(*) as endorsements_number",
        :joins => "endorsements INNER JOIN ideas ON ideas.id = endorsements.idea_id",
        :conditions => ["endorsements.value = 1 and endorsements.user_id in (?)",branch.user_ids], 
        :group => "endorsements.idea_id")
      
      row = 0
      for e in endorsement_scores
        row += 1
        be = branch.endorsements.find_or_create_by_idea_id(e.idea_id.to_i)
        be.score = e.score.to_i
        be.endorsements_count = e.endorsements_number.to_i
        be.position = row
        down = down_endorsement_counts.detect {|d| d.idea_id == e.idea_id.to_i }
        if down
          be.down_endorsements_count = down.endorsements_number.to_i
        else
          be.down_endorsements_count = 0
        end
        up = up_endorsement_counts.detect {|d| d.idea_id == e.idea_id.to_i }
        if up
          be.up_endorsements_count = up.endorsements_number.to_i
        else
          be.up_endorsements_count = 0
        end            
        be.save(:validate => false)
      end          
    end
  end
  
  desc "idea charts"
  task :idea_charts => :environment do
    [14,13,12,11,10,9,8,7,6,5,4,3,2,1].each do |daysminus|
      date = (Time.now-daysminus.days)-4.hours-1.day
      last_week_date = (Time.now-daysminus.days)-4.hours-8.day
      puts "Processing: #{date}"
      previous_date = date-1.day
      start_date = date.year.to_s + "-" + date.month.to_s + "-" + date.day.to_s
      start_date_last_week = last_week_date.year.to_s + "-" + last_week_date.month.to_s + "-" + last_week_date.day.to_s
      end_date = (date+1.day).year.to_s + "-" + (date+1.day).month.to_s + "-" + (date+1.day).day.to_s
      if true or IdeaChart.count(:conditions => ["date_year = ? and date_month = ? and date_day = ?", date.year, date.month, date.day]) == 0  # check to see if it's already been done for yesterday
        puts "Doing chart"
        ideas = Idea.published.find(:all)
        for p in ideas
          # find the ranking
          puts "Idea id: #{p.id}"
          r = p.rankings.find(:all, :conditions => ["rankings.created_at between ? and ?",start_date,end_date], :order => "created_at desc",:limit => 1)
          unless r.any?
            puts "Using last 8 days"
            r = p.rankings.find(:all, :conditions => ["rankings.created_at between ? and ?",start_date_last_week,end_date], :order => "created_at desc",:limit => 1)
          end
          if r.any?
            puts "#{date} - Processing chart position #{r[0].position}!"
            c = p.charts.find_by_date_year_and_date_month_and_date_day(date.year,date.month,date.day)
            if not c
              c = IdeaChart.new(:idea => p, :date_year => date.year, :date_month => date.month, :date_day => date.day)
              puts "Creating new chart"
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
#        for u in User.active.at_least_one_endorsement.all
#          u.index_24hr_delta = u.index_delta_percent(2)
#          u.index_7days_delta = u.index_delta_percent(7)
#          u.index_30days_delta = u.index_delta_percent(30)
#          u.save(:validate => false)
#          u.expire_charts
#        end       
      end
    end
  end
end
