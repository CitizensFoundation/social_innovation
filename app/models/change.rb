class Change < ActiveRecord::Base

  scope :suggested, :conditions => "changes.status = 'suggested'"
  scope :notsent, :conditions => "changes.status = 'notsent'"
  scope :sent, :conditions => "changes.status = 'sent'"  
  scope :approved, :conditions => "changes.status = 'approved'"
  scope :declined, :conditions => "changes.status = 'declined'"  
  scope :voting, :conditions => "changes.status in ('approved','declined','sent')"
  
  scope :active, :conditions => "changes.status in ('sent','suggested')"
  scope :inactive, :conditions => "changes.status in ('notsent','approved','declined')"
  scope :not_removed, :conditions => "changes.status <> 'removed'"
  scope :removed, :conditions => "changes.status = 'removed'"

  scope :by_recently_created, :order => "changes.created_at desc"
  scope :by_recently_started, :order => "changes.sent_at desc"  
  scope :by_recently_updated, :order => "changes.updated_at desc"  

  scope :item_limit, lambda{|limit| {:limit=>limit}}

  belongs_to :idea
  belongs_to :new_idea, :class_name => "Idea", :foreign_key => "new_idea_id"
  belongs_to :user
  
  has_many :votes, :dependent => :destroy
  has_many :activities, :dependent => :destroy
  has_many :notifications, :as => :notifiable, :dependent => :destroy
    
  def validate
    if user.capitals_count < calculate_cost
      errors.add(:base, tr("You dont have enough captial to suggest a takeover", "model/change"))
    end
    if new_idea == idea
      errors.add(:base, tr("You cant suggest a take over of the same idea", "model/change"))
    end
    if not is_endorsers and not is_opposers
      errors.add(:base, tr("You must select either supporters or opposers", "model/change"))
    end
    if idea.has_change?
      errors.add(:base, tr("This idea already has a take over in progress", "model/change"))
    end
  end
  
  validates_presence_of :idea, :user
  validates_presence_of :new_idea, :message => tr("Could not find, make sure you entered it correctly", "model/change")
  validates_length_of :content, :maximum => 500, :allow_nil => true, :allow_blank => true  
  
  acts_as_list

  include Workflow
  workflow_column :status
  workflow do
    state :suggested do
      event :send, transitions_to: :sent
      event :dont_send, transitions_to: :notsent
      event :approve, transitions_to: :approved
      event :decline, transitions_to: :declined
      event :remove, transitions_to: :removed
    end
    state :sent do
      event :approve, transitions_to: :approved
      event :decline, transitions_to: :declined
      event :remove, transitions_to: :removed
    end
    state :notsent
    state :approved do
      event :remove, transitions_to: :removed
    end
    state :declined do
      event :remove, transitions_to: :removed
    end
    state :remove
  end

  after_create :add_to_idea
  after_create :log_activity
  before_create :add_cost
  
  def calculate_estimated_votes_count
    ballots = 0
    ballots += idea.up_endorsements_count if is_endorsers?
    ballots += idea.down_endorsements_count if is_opposers?
    return ballots
  end  
  
  def per_user_cost
    0.01
  end
  
  def cost_opposers
    return 0 if idea.down_endorsements_count == 0
    (idea.down_endorsements_count*per_user_cost).to_i+1
  end
  
  def cost_endorsers
    return 0 if idea.up_endorsements_count == 0    
    (idea.up_endorsements_count*per_user_cost).to_i+1
  end  
  
  def calculate_cost
    (calculate_estimated_votes_count*per_user_cost).to_i+1
  end
  
  def add_cost
    self.cost = calculate_cost
    self.estimated_votes_count = calculate_estimated_votes_count
  end
  
  cattr_reader :per_page
  @@per_page = 15
  
  def log_activity
    user.increment(:changes_count)
    @activity = ActivityCapitalAcquisitionProposal.create(:user => user, :idea => idea, :change => self, :capital => CapitalAcquisitionProposal.create(:sender => user, :amount => self.cost))
    for u in User.active.admins.all
      notifications << NotificationChangeProposed.new(:sender => user, :recipient => u) if u.id != user.id
    end
    if self.attribute_present?("content")
      @comment = @activity.comments.new
      @comment.content = content
      @comment.user = user
      if idea
        # if this is related to a idea, check to see if they endorse it
        e = idea.endorsements.active_and_inactive.find_by_user_id(user.id)
        @comment.is_endorser = true if e and e.is_up?
        @comment.is_opposer = true if e and e.is_down?
      end
      @comment.save(:validate => false)
    end
  end  
  
  def add_to_idea
    idea.update_attribute(:change_id,id)
  end

  def new_idea_name
    new_idea.name if new_idea
  end
  
  def new_idea_name=(n)
    self.new_idea = Idea.find_by_name(n) unless n.blank?
  end
  
  def idea_name
    idea.name if idea
  end
  
  def idea_name=(n)
    self.idea = Idea.find_by_name(n) unless n.blank?
  end  
  
  def time_left
    return '0 mins' if self.is_expired?
    amt = (self.sent_at+2.days) - Time.now
    minutes = (amt/60).round
    hours = (minutes/60).round
    minutes_left = minutes - (hours*60)
    if hours < 1
      return minutes_left.to_s + " #{tr("min", "model/change")}."
    elsif hours == 1
      return hours.to_s + " #{tr("hr", "model/change")} " + minutes_left.to_s + " #{tr("min", "model/change")}."      
    else
      return hours.to_s + " #{tr("hr", "model/change")} " + minutes_left.to_s + " #{tr("min", "model/change")}."
    end
  end
  
  def past_changes
    Change.find(:all, :conditions => ["status in ('sent','approved','declined') and id <> ? and ((idea_id = ? and new_idea_id = ?) or (idea_id = ? and new_idea_id = ?))",self.id,self.idea_id,self.new_idea_id,self.new_idea_id,self.idea_id])    
  end
  
  def past_change_ids
    past_changes.collect{|c| c.id}    
  end
    
  def past_voters
    Vote.find(:all, :conditions => ["change_id in (?)",past_change_ids] )
  end
  
  def past_voter_ids
    past_voters.collect{|c| c.user_id}
  end
  
  def on_sent_entry(new_state, event)
    ballots = 0
    if is_endorsers?
      for u in idea.up_endorsers
        v = Vote.new(:user => u, :change => self) 
        if is_flip?        
          v.value = -1 
        else
          v.value = 1
        end
        v.save(:validate => false)
        ballots += 1
      end
    end
    if is_opposers?
      for u in idea.down_endorsers
        v = Vote.new(:user => u, :change => self) 
        if is_flip?        
          v.value = 1 
        else
          v.value = -1
        end
        v.save(:validate => false)
        ballots += 1
      end
    end
    self.votes_count = ballots
    self.sent_at = Time.now
    remove_notifications    
  end
  
  # this method is based on not including folks who have voted on this acquisition in the past
  #def on_sent_entry(new_state, event)
  #  if is_up?
  #    eusers = idea.up_endorsers
  #  elsif is_down?
  #    eusers = idea.down_endorsers
  #  elsif is_both?
  #    eusers = idea.endorsers
  #  end
  #  ballots = 0    
  #  for u in eusers
  #    if not past_voter_ids.include?(u.id)
  #      v = Vote.create(:user => u, :change => self) 
  #      ballots += 1
  #      # v.send! -- don't send it anymore, it gets batched once a day
  #    end
  #  end
  #  self.votes_count = ballots
  #  self.sent_at = Time.now
  #end
  
  def on_notsent_entry(new_state, event)
    idea.update_attribute(:change_id,nil)    
    # refund their political capital
    if self.has_cost?
      ActivityCapitalAcquisitionProposalDeleted.create(:user => user, :idea => idea, :change => self, :capital => CapitalAcquisitionProposalDeleted.create(:recipient => user, :amount => self.cost))
    end
    remove_notifications    
  end  
  
  def on_approved_entry(new_state, event)
    self.approved_at = Time.now
    save(:validate => false)
    for vote in self.votes.pending
      vote.implicit_approve!
    end
    # uncommenting this would remove the change_id from the acquired idea, messing up the replaced functionality
    # idea.update_attribute(:change_id,nil) 
    idea.reload
    idea.deactivate! if idea.endorsements.length == 0
    ActivityIdeaAcquisitionProposalApproved.create(:change => self, :idea => idea, :user => user)
    # reward them with more political capital because it was such a success
    if self.has_cost?
      ActivityCapitalAcquisitionProposalApproved.create(:user => user, :idea => idea, :change => self, :capital => CapitalAcquisitionProposalApproved.create(:recipient => user, :amount => self.cost*2))
    end
    remove_notifications    
  end
  
  def insta_approve!
    approve!
    if is_flip?
      idea.flip_into(new_idea_id,true)
    else
      idea.merge_into(new_idea_id,true)
    end
    remove_notifications    
  end
  
  def on_declined_entry(new_state, event)
    self.declined_at = Time.now
    save(:validate => false)
    idea.update_attribute(:change_id,nil)    
    for vote in self.votes.pending
      vote.implicit_decline!
    end
    ActivityIdeaAcquisitionProposalDeclined.create(:change => self, :idea => idea, :user => user)
    remove_notifications    
  end
  
  def on_removed_entry(new_state, event)
    idea.update_attribute(:change_id,nil)    
    # refund their political capital
    if has_cost?
      ActivityCapitalAcquisitionProposalDeleted.create(:user => user, :idea => idea, :change => self, :capital => CapitalAcquisitionProposalDeleted.create(:recipient => user, :amount => self.cost))
    end
    remove_notifications
  end
  
  def remove_notifications
    for n in notifications
      n.destroy
    end
    return true
  end

  def has_reason?
    attribute_present?("content")
  end
  
  def has_cost?
    attribute_present?("cost") and cost > 0
  end  
  
  def total_votes
    yes_votes + no_votes
  end
  
  def is_voting?
    self.status == 'sent'
  end
  
  def is_passing?
    return true if (yes_votes+no_votes) == 0
    (yes_votes.to_f/total_votes.to_f) >= 0.70
  end
  
  def is_failing?
    not is_passing?
  end
  
  def is_active?
    ['sent','suggested'].include?(status)
  end
  
  def is_expired?
    return true if ['approved','declined','notsent'].include?(status)
    return false if not self.attribute_present?("sent_at")
    Time.now > (self.sent_at+2.days)
  end
  
  def show_url
    idea.show_url + '/changes/' + id.to_s
  end
  
end
