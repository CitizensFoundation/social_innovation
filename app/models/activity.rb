class Activity < ActiveRecord::Base
  
  acts_as_set_sub_instance :table_name=>"activities"
  
  scope :active, :conditions => "activities.status = 'active'"
  scope :deleted, :conditions => "activities.status = 'deleted'", :order => "updated_at desc"
  scope :for_all_users, :conditions => "is_user_only=false"

  scope :discussions, :conditions => "activities.comments_count > 0"
  scope :changes, :conditions => "change_id is not null"
  scope :points, :conditions => "type like 'ActivityPoint%'", :order => "activities.created_at desc"
  scope :points_and_docs, :conditions => "type like 'ActivityPoint%' or type like 'ActivityDocument%'", :order => "activities.created_at desc"
  scope :capital, :conditions => "type like '%Capital%'"
  scope :interesting, :conditions => "type in ('ActivityPriorityMergeProposal','ActivityPriorityAcquisitionProposal') or comments_count > 0"

  scope :top, :order=>"changed_at DESC", :conditions => "type in ('ActivityPointNew','ActivityDocumentNew','ActivityPriorityNew','ActivityBulletinNew')"
  scope :top_discussions, :order=>"changed_at DESC", :conditions => "type in ('ActivityBulletinNew')", :limit=>5
  scope :with_20, :limit=> 20

  scope :feed, lambda{|last| {:conditions=>["changed_at < ? ", last], :order=>"changed_at DESC", :limit=>5}}
  scope :last_three_days, :conditions => "activities.changed_at > '#{Time.now-3.days}'"
  scope :last_seven_days, :conditions => "activities.changed_at > '#{Time.now-7.days}'"
  scope :last_thirty_days, :conditions => "activities.changed_at > '#{Time.now-30.days}'"    
  scope :last_24_hours, :conditions => "created_at > '#{Time.now-24.hours}')"  
  
  scope :by_recently_updated, :order => "activities.changed_at desc"  
  scope :by_recently_created, :order => "activities.created_at desc"    

  scope :item_limit, lambda{|limit| {:limit=>limit}}
    scope :by_tag_name, lambda{|tag_name| {:conditions=>["cached_issue_list=?",tag_name]}}

  scope :by_user_id, lambda{|user_id| {:conditions=>["user_id=?",user_id]}}

  belongs_to :user
  belongs_to :sub_instance
  
  belongs_to :other_user, :class_name => "User", :foreign_key => "other_user_id"
  belongs_to :priority
  belongs_to :activity
  belongs_to :change
  belongs_to :vote
  belongs_to :tag
  belongs_to :point
  belongs_to :revision
  belongs_to :document
  belongs_to :document_revision
  belongs_to :capital
  belongs_to :ad

  belongs_to :priority_status_change_log
  has_many :comments, :order => "comments.created_at asc", :dependent => :destroy
  has_many :published_comments, :class_name => "Comment", :foreign_key => "activity_id", :conditions => "comments.status = 'published'", :order => "comments.created_at asc"
  has_many :commenters, :through => :published_comments, :source => :user, :select => "DISTINCT users.*"
  has_many :activities, :dependent => :destroy
  has_many :notifications, :as => :notifiable, :dependent => :destroy
  has_many :followings, :class_name => "FollowingDiscussion", :foreign_key => "activity_id", :dependent => :destroy
  has_many :followers, :through => :followings, :source => :user, :select => "DISTINCT users.*"

  include Workflow
  workflow_column :status
  workflow do
    state :active do
      event :delete, transitions_to: :deleted
    end

    state :deleted do
      event :undelete, transitions_to: :active
    end
  end

  before_save :update_changed_at
  
  def update_changed_at
    self.changed_at = Time.now unless self.attribute_present?("changed_at")
  end

  def multi_name
    return "test x"
    if self.priority_id
      self.priority.name
    elsif self.point_id
      self.question.name
    elsif self.document_id
      self.document.name
    else
      "#{self.inspect}"
    end
  end

  def show_multi_url
    return "test m"
    if self.priority_id
      self.priority.show_url
    elsif self.point_id
      self.point.show_url
    elsif self.document_id
      self.document.show_url
    else
      "#{self.inspect}"
    end
  end

  def on_deleted_entry(new_state, event)
    # go through and mark all the comments as deleted
    for comment in published_comments
      comment.delete!
    end
  end

  cattr_reader :per_page
  @@per_page = 25

  def commenters_count
    comments.count(:group => :user, :order => "count_all desc")
  end  

  def is_official_user?
    return false unless Instance.current.has_official?
    user_id == Instance.current.official_user_id
  end

  def has_priority?
    attribute_present?("priority_id")
  end
  
  def has_activity?
    attribute_present?("activity_id")
  end
  
  def has_user?
    attribute_present?("user_id")
  end    
  
  def has_other_user?
    attribute_present?("other_user_id")
  end  
  
  def has_point?
    attribute_present?("point_id")
  end
  
  def has_change?
    attribute_present?("change_id")
  end
  
  def has_capital?
    attribute_present?("capital_id")
  end  
  
  def has_revision?
    attribute_present?("revision_id")
  end    
  
  def has_document?
    attribute_present?("document_id")
  end  
  
  def has_document_revision?
    attribute_present?("document_revision_id")
  end  
  
  def has_ad?
    attribute_present?("ad_id") and ad
  end
  
  def has_comments?
    comments_count > 0
  end
  
  def first_comment
    comments.published.first
  end
  
  def last_comment
    comments.published.last
  end
  
end

class ActivityUserNew < Activity
  def name
    tr("{user_name} joined {instance_name}", "model/activity", :user_name => user.name, :instance_name => Instance.current.name)
  end
end

# Jerry invited Jonathan to join
class ActivityInvitationNew < Activity
  def name
    if user 
      tr("{user_name} invited someone to join", "model/activity", :user_name => user.login)
    else
      tr("{user_name} invited someone to join", "model/activity", :user_name => "Someone")
    end
  end
end

# Jonathan accepted Jerry's invitation to join
class ActivityInvitationAccepted < Activity
  def name
    if other_user
      tr("{user_name} accepted an invitation from {other_user_name} to join {instance_name}", "model/activity", :user_name => user.name, :other_user_name => other_user.name, :instance_name => Instance.current.name)
    else
      tr("{user_name} accepted an invitation to join {instance_name}", "model/activity", :user_name => user.name, :instance_name => Instance.current.name)
    end
  end  
end

# Jerry recruited Jonathan to White House 2.
class ActivityUserRecruited < Activity
  
  after_create :add_capital
  
  def add_capital
    ActivityCapitalUserRecruited.create(:user => user, :other_user => other_user, :capital => CapitalUserRecruited.new(:recipient => user, :amount => 5))
  end
  
  def name
    tr("{user_name} recruited {other_user_name} to {instance_name}", "model/activity", :user_name => user.name, :other_user_name => other_user.name, :instance_name => Instance.current.name)
  end
end

class ActivityCapitalUserRecruited < Activity
  def name
    tr("{user_name} earned {capital}{currency_short_name} for recruiting {other_user_name} to {instance_name}", "model/activity", :user_name => user.name, :other_user_name => other_user.name, :instance_name => Instance.current.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
  end
end

class ActivityPartnerUserRecruited < Activity
  
  def name
    tr("{user_name} recruited {other_user_name} to {instance_name} through {sub_instance_url}", "model/activity", :user_name => user.name, :other_user_name => other_user.name, :instance_name => Instance.current.name, :sub_instance_url => sub_instance.short_name + '.' + Instance.current.base_url)
  end
  
end

class ActivityCapitalPartnerUserRecruited < Activity
  def name
    tr("{user_name} earned {capital}{currency_short_name} for recruiting {other_user_name} to {instance_name} through {sub_instance_url}", "model/activity", :user_name => user.name, :other_user_name => other_user.name, :instance_name => Instance.current.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name, :sub_instance_url => sub_instance.short_name + '.' + Instance.current.base_url)
  end
end

class ActivityPriorityDebut < Activity
  
  def name
    if attribute_present?("position")
      tr("{priority_name} debuted on the charts at {position}", "model/activity", :priority_name => priority.name, :position => position)
    else
      tr("{priority_name} debuted on the charts", "model/activity", :priority_name => priority.name)
    end
  end
  
end

class ActivityUserRankingDebut < Activity
  
  def name
    if attribute_present?("position")
      tr("{user_name} debuted on the most influential chart at {position}", "model/activity", :user_name => user.name, :position => position)
    else
      tr("{user_name} debuted on the most influential chart", "model/activity", :user_name => user.name)
    end
  end
  
end

class ActivityEndorsementNew < Activity

  def name
    if has_ad?
      if attribute_present?("position")
        tr("{user_name} endorsed {priority_name} at priority {position} due to {ad_user} ad", "model/activity", :user_name => user.name, :priority_name => priority.name, :position => position, :ad_user => ad.user.name.possessive)
      else
        tr("{user_name} endorsed {priority_name} due to {ad_user} ad", "model/activity", :user_name => user.name, :priority_name => priority.name, :ad_user => ad.user.name.possessive)
      end      
    else
      if attribute_present?("position")
        tr("{user_name} endorsed {priority_name} at priority {position}", "model/activity", :user_name => user.name, :priority_name => priority.name, :position => position)
      else
        tr("{user_name} endorsed {priority_name}", "model/activity", :user_name => user.name, :priority_name => priority.name)
      end
    end
  end  
  
end

class ActivityEndorsementDelete < Activity
  def name
    tr("{user_name} no longer endorses {priority_name}", "model/activity", :user_name => user.name, :priority_name => priority.name)
  end
end

class ActivityOppositionNew < Activity
  
  def name
    if has_ad?
      if attribute_present?("position")
        tr("{user_name} opposed {priority_name} at priority {position} due to {ad_user} ad", "model/activity", :user_name => user.name, :priority_name => priority.name, :position => position, :ad_user => ad.user.name.possessive)
      else
        tr("{user_name} opposed {priority_name} due to {ad_user} ad", "model/activity", :user_name => user.name, :priority_name => priority.name, :ad_user => ad.user.name.possessive)
      end      
    else
      if attribute_present?("position")
        tr("{user_name} opposed {priority_name} at priority {position}", "model/activity", :user_name => user.name, :priority_name => priority.name, :position => position)
      else
        tr("{user_name} opposed {priority_name}", "model/activity", :user_name => user.name, :priority_name => priority.name)
      end
    end
  end  
  
end

class ActivityOppositionDelete < Activity
  def name
    tr("{user_name} no longer opposes {priority_name}", "model/activity", :user_name => user.name, :priority_name => priority.name)
  end
end

class ActivityEndorsementReplaced < Activity
  def name
    tr("{user_name} endorsed {new_priority_name} instead of {priority_name}", "model/activity", :user_name => user.name, :priority_name => priority.name, :new_priority_name => change.new_priority.name)
  end  
end

class ActivityEndorsementReplacedImplicit < Activity
  def name
    tr("{user_name} is now endorsing {new_priority_name} because {priority_name} was acquired", "model/activity", :user_name => user.name, :priority_name => priority.name, :new_priority_name => change.new_priority.name)
  end
end

class ActivityEndorsementFlipped < Activity
  def name
    tr("{user_name} endorsed {new_priority_name} instead of opposing {priority_name}", "model/activity", :user_name => user.name, :priority_name => priority.name, :new_priority_name => change.new_priority.name)    
  end
end

class ActivityEndorsementFlippedImplicit < Activity
  def name
    tr("{user_name} is now endorsing {new_priority_name} because it acquired the opposers of {priority_name}", "model/activity", :user_name => user.name, :priority_name => priority.name, :new_priority_name => change.new_priority.name)    
  end
end

class ActivityOppositionReplaced < Activity
  def name
    tr("{user_name} opposed {new_priority_name} instead of {priority_name}", "model/activity", :user_name => user.name, :priority_name => priority.name, :new_priority_name => change.new_priority.name)
  end
end

class ActivityOppositionReplacedImplicit < Activity
  def name
    tr("{user_name} is now opposing {new_priority_name} because {priority_name} was acquired", "model/activity", :user_name => user.name, :priority_name => priority.name, :new_priority_name => change.new_priority.name)
  end
end

class ActivityOppositionFlipped < Activity
  def name
    tr("{user_name} opposed {new_priority_name} instead of opposing {priority_name}", "model/activity", :user_name => user.name, :priority_name => priority.name, :new_priority_name => change.new_priority.name)    
  end
end

class ActivityOppositionFlippedImplicit < Activity
  def name
    tr("{user_name} is now endorsing {new_priority_name} because it acquired the opposers of {priority_name}", "model/activity", :user_name => user.name, :priority_name => priority.name, :new_priority_name => change.new_priority.name) 
  end
end

class ActivityPartnerNew < Activity
  def name
    tr("{sub_instance_name} is a new sub_instance", "model/activity", :sub_instance_name => sub_instance.name)
  end
end

class ActivityPriorityNew < Activity
  def name
    tr("{user_name} first suggested {priority_name}", "model/activity", :user_name => user.name, :priority_name => priority.name)     
  end  
end

# [user name] flagged [priority name] as inappropriate.
class ActivityPriorityFlagInappropriate < Activity
  
  def name
    tr("{user_name} flagged {priority_name} for review", "model/activity", :user_name => user.name, :priority_name => priority.name)     
  end  
  
  validates_uniqueness_of :user_id, :scope => [:priority_id], :message => "You've already flagged this."
  
end

class ActivityPriorityFlag < Activity
  
  def name
    tr("{user_name} flagged {priority_name} for review", "model/activity", :user_name => user.name, :priority_name => priority.name)  
  end  

  after_create :notify_admin
  
  def notify_admin
    for r in User.active.admins
      priority.notifications << NotificationPriorityFlagged.new(:sender => user, :recipient => r) if r.id != user.id
    end
  end
  
end

# [user name] buried [priority name].
class ActivityPriorityBury < Activity
  def name
    tr("{user_name} buried {priority_name}. It's probably obvious why.", "model/activity", :user_name => user.name, :priority_name => priority.name)  
  end
end

# identifies that a person is participating in a discussion about another activity
# is_user_only!  it's not meant to be shown on the priority page, just on the user page
# and it's only supposed to be invoked once, when they first start discussing an activity
# but the updated_at should be updated on subsequent postings in the discussion
class ActivityCommentParticipant < Activity
 
  def name
    tr("{user_name} left {count} comments on {discussion_name}", "model/activity", :user_name => user.name, :count => comments_count, :discussion_name => activity.name)  
  end
  
end

class ActivityDiscussionFollowingNew < Activity
  def name
    tr("{user_name} is following the discussion on {discussion_name}", "model/activity", :user_name => user.name, :discussion_name => activity.name)
  end
end

class ActivityDiscussionFollowingDelete < Activity
  def name
    tr("{user_name} stopped following the discussion on {discussion_name}", "model/activity", :user_name => user.name, :discussion_name => activity.name)
  end
end

class ActivityPriorityCommentNew < Activity
  def name
    tr("{user_name} left a comment on {priority_name}", "model/activity", :user_name => user.name, :priority_name => priority.name)  
  end
end

class ActivityBulletinProfileNew < Activity
  
  def send_notification
    notifications << NotificationProfileBulletin.new(:sender => self.other_user, :recipient => self.user)       
  end
  
  def name
    tr("{user_name} posted a bulletin to {other_user_name} profile", "model/activity", :user_name => other_user.name, :other_user_name => user.name.possessive)  
  end
  
end

class ActivityBulletinProfileAuthor < Activity
  
  def name
    tr("{user_name} posted a bulletin to {other_user_name} profile", "model/activity", :user_name => user.name, :other_user_name => other_user.name.possessive)      
  end
  
end

class ActivityBulletinNew < Activity
  
  def name
    if point
      tr("{user_name} posted a bulletin to {discussion_name}", "model/activity", :user_name => user.name, :discussion_name => point.name)         
    elsif document
      tr("{user_name} posted a bulletin to {discussion_name}", "model/activity", :user_name => user.name, :discussion_name => document.name)
    elsif priority
      tr("{user_name} posted a bulletin to {discussion_name}", "model/activity", :user_name => user.name, :discussion_name => priority.name)
    else
      tr("{user_name} posted a bulletin", "model/activity", :user_name => user.name)
    end
  end
  
end

class ActivityPriority1 < Activity
  def name
    tr("{priority_name} is {user_name} new #1 priority", "model/activity", :user_name => user.name.possessive, :priority_name => priority.name)
  end
end

class ActivityPriority1Opposed < Activity
  def name
    tr("Opposing {priority_name} is {user_name} new #1 priority", "model/activity", :user_name => user.name.possessive, :priority_name => priority.name)
  end
end

class ActivityPriorityRising1 < Activity
  def name
    tr("{priority_name} is the fastest rising priority", "model/activity", :priority_name => priority.name)
  end
end

class ActivityIssuePriority1 < Activity
  def name
    tr("{priority_name} is the new #1 priority in {tag_name}", "model/activity", :priority_name => priority.name, :tag_name => tr(tag.title,"model/category"))
  end
end

class ActivityIssuePriorityControversial1 < Activity
  def name
    tr("{priority_name} is the most controversial priority in {tag_name}", "model/activity", :priority_name => priority.name, :tag_name => tr(tag.title,"model/category"))
  end
end

class ActivityIssuePriorityRising1 < Activity
  def name
    tr("{priority_name} is the fastest rising priority in {tag_name}", "model/activity", :priority_name => priority.name, :tag_name => tr(tag.title,"model/category"))
  end
end

class ActivityIssuePriorityOfficial1 < Activity
  def name
    tr("{priority_name} is the new #1 priority on {official_user_name} {tag_name} agenda", "model/activity", :priority_name => priority.name, :tag_name => tr(tag.title,"model/category"), :official_user_name => Instance.current.official_user.name.possessive)
  end
end

class ActivityPriorityMergeProposal < Activity
  def name
    tr("{user_name} proposed {new_priority_name} acquire {priority_name}", "model/activity", :user_name => user.name, :priority_name => priority.name, :new_priority_name => change.new_priority.name)    
  end
end

class ActivityPriorityRenamed < Activity
  def name
    tr("{user_name} renamed {priority_name}", "model/activity", :user_name => user.name, :priority_name => priority.name)  
  end
end

class ActivityPointNew < Activity
  
  def name
    tr("{user_name} added {point_name} to {priority_name}", "model/activity", :user_name => user.name, :point_name => point.name, :priority_name => priority.name)      
  end
  
end

class ActivityPointDeleted < Activity
  def name
    tr("{user_name} deleted {point_name}", "model/activity", :user_name => user.name, :point_name => point.name)      
  end
end

class ActivityPointRevisionContent < Activity
  def name
    tr("{user_name} revised {point_name}", "model/activity", :user_name => user.name, :point_name => point.name)      
  end
end

class ActivityPointRevisionName < Activity
  def name
    tr("{user_name} changed the point's title to {point_name}", "model/activity", :user_name => user.name, :point_name => point.name)
  end
end

class ActivityPointRevisionOtherPriority < Activity
  def name
    if revision.has_other_priority?
      tr("{user_name} linked {point_name} to {priority_name}", "model/activity", :user_name => user.name, :point_name => point.name, :priority_name => revision.other_priority.name)
    else
      tr("{user_name} removed the priority link from {point_name}", "model/activity", :user_name => user.name, :point_name => point.name)
    end
  end
end

class ActivityPointRevisionWebsite < Activity
  def name
    if revision.has_website?
      tr("{user_name} revised the source link for {point_name}", "model/activity", :user_name => user.name, :point_name => point.name)
    else
      tr("{user_name} removed the source link from {point_name}", "model/activity", :user_name => user.name, :point_name => point.name)
    end
  end
end

class ActivityPointRevisionSupportive < Activity
  def name
    tr("{user_name} revised {point_name} to indicate it's supportive of {priority_name}", "model/activity", :user_name => user.name, :point_name => point.name, :priority_name => priority.name)    
  end
end

class ActivityPointRevisionNeutral < Activity
  def name
    tr("{user_name} revised {point_name} to indicate it's neutral on {priority_name}", "model/activity", :user_name => user.name, :point_name => point.name, :priority_name => priority.name)    
  end
end

class ActivityPointRevisionOpposition < Activity
  def name
    tr("{user_name} revised {point_name} to indicate it's opposed to {priority_name}", "model/activity", :user_name => user.name, :point_name => point.name, :priority_name => priority.name)    
  end
end

class ActivityPointHelpful < Activity
  def name
    tr("{user_name} marked {point_name} helpful", "model/activity", :user_name => user.name, :point_name => point.name)    
  end
end

class ActivityPointUnhelpful < Activity
  def name
    tr("{user_name} marked {point_name} unhelpful", "model/activity", :user_name => user.name, :point_name => point.name)    
  end
end

class ActivityPointHelpfulDelete < Activity
  def name
    tr("{user_name} no longer finds {point_name} helpful", "model/activity", :user_name => user.name, :point_name => point.name)    
  end
end

class ActivityPointUnhelpfulDelete < Activity
  def name
    tr("{user_name} no longer finds {point_name} unhelpful", "model/activity", :user_name => user.name, :point_name => point.name)    
  end
end

class ActivityUserPictureNew < Activity
  def name
    tr("{user_name} changed their profile picture", "model/activity", :user_name => user.name)
  end
end

class ActivityPartnerPictureNew < Activity
  def name
    tr("{sub_instance_name} has a new logo", "model/activity", :user_name => user.name, :sub_instance_name => sub_instance.name)
  end
end

class ActivityCapitalPointHelpfulEveryone < Activity
  def name
    if capital.amount > 0
      tr("{user_name} earned {capital}{currency_short_name} because both endorsers and opposers found {point_name} helpful", "model/activity", :user_name => user.name, :point_name => point.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
    elsif capital.amount < 0
      tr("{user_name} lost {capital}{currency_short_name} because both endorsers and opposers found {point_name} unhelpful", "model/activity", :user_name => user.name, :point_name => point.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
    end
  end
end

class ActivityCapitalPointHelpfulEndorsers < Activity
  def name
    if capital.amount > 0
      if capital.is_undo?
        tr("{user_name} earned {capital}{currency_short_name} because endorsers didn't find {point_name} unhelpful anymore", "model/activity", :user_name => user.name, :point_name => point.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
      else
        tr("{user_name} earned {capital}{currency_short_name} because endorsers found {point_name} helpful", "model/activity", :user_name => user.name, :point_name => point.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
      end
    elsif capital.amount < 0
      if capital.is_undo?
        tr("{user_name} lost {capital}{currency_short_name} because endorsers didn't found {point_name} helpful anymore", "model/activity", :user_name => user.name, :point_name => point.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
      else
        tr("{user_name} lost {capital}{currency_short_name} because endorsers found {point_name} unhelpful", "model/activity", :user_name => user.name, :point_name => point.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
      end
    end
  end
end

class ActivityCapitalPointHelpfulOpposers < Activity
  def name
    if capital.amount > 0
      if capital.is_undo?
        tr("{user_name} earned {capital}{currency_short_name} because opposers didn't find {point_name} unhelpful anymore", "model/activity", :user_name => user.name, :point_name => point.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
      else
        tr("{user_name} earned {capital}{currency_short_name} because opposers found {point_name} helpful", "model/activity", :user_name => user.name, :point_name => point.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
      end
    elsif capital.amount < 0
      if capital.is_undo?
        tr("{user_name} lost {capital}{currency_short_name} because opposers didn't find {point_name} helpful anymore", "model/activity", :user_name => user.name, :point_name => point.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
      else
        tr("{user_name} lost {capital}{currency_short_name} because opposers found {point_name} unhelpful", "model/activity", :user_name => user.name, :point_name => point.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
      end
    end
  end
end

class ActivityCapitalPointHelpfulUndeclareds < Activity
  def name
    if capital.amount > 0
      if capital.is_undo?
        tr("{user_name} earned {capital}{currency_short_name} because undeclareds didn't find {point_name} unhelpful anymore", "model/activity", :user_name => user.name, :point_name => point.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
      else
        tr("{user_name} earned {capital}{currency_short_name} because undeclareds found {point_name} helpful", "model/activity", :user_name => user.name, :point_name => point.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
      end
    elsif capital.amount < 0
      if capital.is_undo?
        tr("{user_name} lost {capital}{currency_short_name} because undeclareds didn't find {point_name} helpful anymore", "model/activity", :user_name => user.name, :point_name => point.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)

      else
        tr("{user_name} lost {capital}{currency_short_name} because undeclareds found {point_name} unhelpful", "model/activity", :user_name => user.name, :point_name => point.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
      end
    end
  end
end

class ActivityCapitalPointHelpfulDeleted < Activity
  def name
      tr("{user_name} lost {capital}{currency_short_name} for deleting {point_name} because people found it helpful", "model/activity", :user_name => user.name, :point_name => point.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
  end
end

# this is currently turned off, but the idea was to give capital for followers on twitter.
class ActivityCapitalTwitterFollowers < Activity
  def name
    if capital.amount > 0
      tr("{user_name} earned {count}{currency_short_name} for {count} new followers on Twitter", "model/activity", :user_name => user.name, :count => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
    elsif capital.amount < 0
      tr("{user_name} lost {count}{currency_short_name} for {count} less followers on Twitter", "model/activity", :user_name => user.name, :count => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
    end
  end
end

class ActivityCapitalFollowers < Activity
  def name
    if capital.amount > 0
      tr("{user_name} earned {count}{currency_short_name} for {count} new followers", "model/activity", :user_name => user.name, :count => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
    elsif capital.amount < 0
      tr("{user_name} lost {count}{currency_short_name} for {count} less followers", "model/activity", :user_name => user.name, :count => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
    end
  end
end

class ActivityCapitalInstanceNew < Activity
  def name
    tr("{user_name} earned {capital}{currency_short_name} for founding this nation", "model/activity", :user_name => user.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
  end
end

class ActivityCapitalAdRefunded < Activity
  def name
    tr("{user_name} was refunded {capital}{currency_short_name} for an ad for priority {priority_name} because the priority is now in progress", "model/activity", :user_name => user.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name, :priority_name => priority.name)
  end
end

class ActivityFollowingNew < Activity
  def name
    tr("{user_name} is now following {other_user_name}", "model/activity", :user_name => user.name, :other_user_name => other_user.name)
  end
end

class ActivityFollowingDelete < Activity
  def name
    tr("{user_name} stopped following {other_user_name}", "model/activity", :user_name => user.name, :other_user_name => other_user.name)
  end
end

class ActivityCapitalIgnorers < Activity
  def name
    if capital.amount > 0
      tr("{user_name} earned {count}{currency_short_name} because {count} people stopped ignoring", "model/activity", :user_name => user.name, :count => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
    elsif capital.amount < 0
      tr("{user_name} lost {count}{currency_short_name} because {count} people are ignoring", "model/activity", :user_name => user.name, :count => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
    end
  end
end

class ActivityCapitalInactive < Activity
  def name
      tr("{user_name} lost {capital}{currency_short_name} for not logging in recently", "model/activity", :user_name => user.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
  end
end

class ActivityIgnoringNew < Activity
  def name
    tr("{user_name} is ignoring someone", "model/activity", :user_name => user.name, :other_user_name => other_user.name)
  end
end

class ActivityIgnoringDelete < Activity
  def name
    tr("{user_name} stopped ignoring someone", "model/activity", :user_name => user.name, :other_user_name => other_user.name)
  end
end

class ActivityOfficialLetter < Activity
  def name
    tr("{user_name} Activity Official Letter", "model/activity", :user_name => user.name, :official_user_name => Instance.current.official_user.name)
  end
end

class ActivityCapitalOfficialLetter < Activity
  def name
      tr("{user_name} earned {capital}{currency_short_name} for sending their agenda to {official_user_name}", "model/activity", :user_name => user.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name, :official_user_name => Instance.current.official_user.name)
  end
end

class ActivityCapitalAdNew < Activity
  def name
      tr("{user_name} spent {capital}{currency_short_name} on an ad for {priority_name}", "model/activity", :user_name => user.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name, :priority_name => priority.name)
  end
end

class ActivityCapitalAcquisitionProposal < Activity
  def name
      tr("{user_name} spent {capital}{currency_short_name} on a proposal for {new_priority_name} to acquire {priority_name}", "model/activity", :user_name => user.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name, :priority_name => priority.name, :new_priority_name => change.new_priority.name)
  end
end

class ActivityPriorityAcquisitionProposalNo < Activity
  def name
    tr("{user_name} voted against {new_priority_name} acquiring {priority_name}", "model/activity", :user_name => user.name, :priority_name => priority.name, :new_priority_name => change.new_priority.name)    
  end
end

class ActivityPriorityAcquisitionProposalApproved < Activity
  def name
    tr("{new_priority_name} acquired {priority_name}", "model/activity", :priority_name => priority.name, :new_priority_name => change.new_priority.name)
  end
end

class ActivityPriorityAcquisitionProposalDeclined < Activity
  def name
    tr("{new_priority_name} failed to acquire {priority_name}", "model/activity", :priority_name => priority.name, :new_priority_name => change.new_priority.name)
  end
end

class ActivityPriorityAcquisitionProposalDeleted < Activity
  def name
    tr("{user_name} decided not to hold a vote on {new_priority_name} acquiring {priority_name}", "model/activity", :user_name => user.name, :priority_name => priority.name, :new_priority_name => change.new_priority.name)  
  end
end

class ActivityCapitalAcquisitionProposalDeleted < Activity
  def name
      tr("{user_name} was refunded {capital}{currency_short_name} because no vote will be held on {new_priority_name} acquiring {priority_name}", "model/activity", :user_name => user.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name, :priority_name => priority.name, :new_priority_name => change.new_priority.name)
  end
end

class ActivityCapitalAcquisitionProposalApproved < Activity
  def name
      tr("{user_name} earned {capital}{currency_short_name} because {new_priority_name} successfully acquired {priority_name}", "model/activity", :user_name => user.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name, :priority_name => priority.name, :new_priority_name => change.new_priority.name)
  end
end

class ActivityPriorityOfficialStatusFailed < Activity
  def name
    tr("{priority_name} failed", "model/activity", :priority_name => priority.name)
  end
end

class ActivityPriorityOfficialStatusCompromised < Activity
  def name
    tr("{priority_name} was completed with a compromise", "model/activity", :priority_name => priority.name)
  end
end

class ActivityPriorityOfficialStatusInTheWorks < Activity
  def name
    tr("{priority_name} is in progress", "model/activity", :priority_name => priority.name)
  end
end

class ActivityPriorityOfficialStatusSuccessful < Activity
  def name
    tr("{priority_name} was completed successfully", "model/activity", :priority_name => priority.name)
  end
end

class ActivityPriorityStatusUpdate < Activity
  def name
    tr("{priority_name}'s status was updated", "model/activity", priority_name: priority.name)
  end
end

class ActivityDocumentNew < Activity
  
  def name
    tr("{user_name} added {point_name} to {priority_name}", "model/activity", :user_name => user.name, :point_name => document.name, :priority_name => priority.name)
  end
  
end

class ActivityDocumentDeleted < Activity
  def name
    tr("{user_name} deleted {point_name}", "model/activity", :user_name => user.name, :point_name => document.name)      
  end
end

class ActivityDocumentRevisionContent < Activity
  def name
    tr("{user_name} revised {point_name}", "model/activity", :user_name => user.name, :point_name => document.name)      
  end
end

class ActivityDocumentRevisionName < Activity
  def name
    tr("{user_name} changed the point's title to {point_name}", "model/activity", :user_name => user.name, :point_name => document.name)
  end
end

class ActivityDocumentRevisionSupportive < Activity
  def name
    tr("{user_name} revised {point_name} to indicate it's supportive of {priority_name}", "model/activity", :user_name => user.name, :point_name => document.name, :priority_name => priority.name)    
  end
end

class ActivityDocumentRevisionNeutral < Activity
  def name
    tr("{user_name} revised {point_name} to indicate it's neutral on {priority_name}", "model/activity", :user_name => user.name, :point_name => document.name, :priority_name => priority.name)    
  end
end

class ActivityDocumentRevisionOpposition < Activity
  def name
    tr("{user_name} revised {point_name} to indicate it's opposed to {priority_name}", "model/activity", :user_name => user.name, :point_name => document.name, :priority_name => priority.name)    
  end
end

class ActivityDocumentHelpful < Activity
  def name
    tr("{user_name} marked {point_name} helpful", "model/activity", :user_name => user.name, :point_name => document.name)    
  end
end

class ActivityDocumentUnhelpful < Activity
  def name
    tr("{user_name} marked {point_name} unhelpful", "model/activity", :user_name => user.name, :point_name => document.name)    
  end
end

class ActivityDocumentHelpfulDelete < Activity
  def name
    tr("{user_name} no longer finds {point_name} helpful", "model/activity", :user_name => user.name, :point_name => document.name)    
  end
end

class ActivityDocumentUnhelpfulDelete < Activity
  def name
    tr("{user_name} no longer finds {point_name} unhelpful", "model/activity", :user_name => user.name, :point_name => document.name)    
  end
end

class ActivityCapitalDocumentHelpfulEveryone < Activity
  def name
    if capital.amount > 0
      tr("{user_name} earned {capital}{currency_short_name} because both endorsers and opposers found {point_name} helpful", "model/activity", :user_name => user.name, :point_name => document.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
    elsif capital.amount < 0
      tr("{user_name} lost {capital}{currency_short_name} because both endorsers and opposers found {point_name} unhelpful", "model/activity", :user_name => user.name, :point_name => document.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
    end
  end
end

class ActivityCapitalDocumentHelpfulEndorsers < Activity
  def name
    if capital.amount > 0
      tr("{user_name} earned {capital}{currency_short_name} because endorsers found {point_name} helpful", "model/activity", :user_name => user.name, :point_name => document.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
    elsif capital.amount < 0
      tr("{user_name} lost {capital}{currency_short_name} because endorsers found {point_name} unhelpful", "model/activity", :user_name => user.name, :point_name => document.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
    end
  end
end

class ActivityCapitalDocumentHelpfulOpposers < Activity
  def name
    if capital.amount > 0
      tr("{user_name} earned {capital}{currency_short_name} because opposers found {point_name} helpful", "model/activity", :user_name => user.name, :point_name => document.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
    elsif capital.amount < 0
      tr("{user_name} lost {capital}{currency_short_name} because opposers found {point_name} unelpful", "model/activity", :user_name => user.name, :point_name => document.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
    end
  end
end

class ActivityCapitalDocumentHelpfulUndeclareds < Activity
  def name
    if capital.amount > 0
      tr("{user_name} earned {capital}{currency_short_name} because undeclareds found {point_name} helpful", "model/activity", :user_name => user.name, :point_name => document.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
    elsif capital.amount < 0
      tr("{user_name} lost {capital}{currency_short_name} because undeclares found {point_name} unhelpful", "model/activity", :user_name => user.name, :point_name => document.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
    end
  end
end

class ActivityCapitalDocumentHelpfulDeleted < Activity
  def name
      tr("{user_name} lost {capital}{currency_short_name} for deleting {point_name} because people found it helpful", "model/activity", :user_name => user.name, :point_name => document.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
  end
end

class ActivityCapitalWarning < Activity
  def name
    tr("{user_name} lost {capital}{currency_short_name} for violating the site rules", "model/activity", :user_name => user.name, :capital => capital.amount.abs, :currency_short_name => Instance.current.currency_short_name)
  end
end

class ActivityUserProbation < Activity
  def name
    tr("{user_name} is on probation for a week due to repeated violations of the site rules", "model/activity", :user_name => user.name)
  end
end