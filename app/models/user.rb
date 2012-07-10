require 'digest/sha1'

class User < ActiveRecord::Base
  include Rails.application.routes.url_helpers

  require 'paperclip'

  attr_accessible :buddy_icon

  scope :active, :conditions => "users.status in ('pending','active')"
  scope :at_least_one_endorsement, :conditions => "users.endorsements_count > 0"
  scope :newsletter_subscribed, :conditions => "users.report_frequency != 0 and users.email is not null and users.email <> ''"
  scope :comments_unsubscribed, :conditions => "users.is_comments_subscribed = false"  
  scope :twitterers, :conditions => "users.twitter_login is not null and users.twitter_login <> ''"
  scope :authorized_twitterers, :conditions => "users.twitter_token is not null"
  scope :uncrawled_twitterers, :conditions => "users.twitter_crawled_at is null"
  scope :contributed, :conditions => "users.point_revisions_count > 0"
  scope :no_recent_login, :conditions => "users.loggedin_at < '#{Time.now-90.days}'"
  scope :admins, :conditions => "users.is_admin = true"
  scope :suspended, :conditions => "users.status = 'suspended'"
  scope :probation, :conditions => "users.status = 'probation'"
  scope :removed, :conditions => "users.status = 'removed'"
  scope :pending, :conditions => "users.status = 'pending'"  
  scope :warnings, :conditions => "warnings_count > 0"
  
  scope :by_capital, :order => "users.capitals_count desc, users.score desc"
  scope :by_ranking, :conditions => "users.position > 0", :order => "users.position asc"  
  scope :by_talkative, :conditions => "users.comments_count > 0", :order => "users.comments_count desc"
  scope :by_twitter_count, :order => "users.twitter_count desc"
  scope :by_recently_created, :order => "users.created_at desc"
  scope :by_revisions, :order => "users.point_revisions_count desc"
  scope :by_invites_accepted, :conditions => "users.contacts_invited_count > 0", :order => "users.referrals_count desc"
  scope :by_suspended_at, :order => "users.suspended_at desc"
  scope :by_removed_at, :order => "users.removed_at desc"
  scope :by_recently_loggedin, :order => "users.loggedin_at desc"
  scope :by_probation_at, :order => "users.probation_at desc"
  scope :by_oldest_updated_at, :order => "users.updated_at asc"
  scope :by_twitter_crawled_at, :order => "users.twitter_crawled_at asc"
  
  scope :by_24hr_gainers, :conditions => "users.endorsements_count > 4", :order => "users.index_24hr_delta desc"
  scope :by_24hr_losers, :conditions => "users.endorsements_count > 4", :order => "users.index_24hr_delta asc"  
  scope :by_7days_gainers, :conditions => "users.endorsements_count > 4", :order => "users.index_7days_delta desc"
  scope :by_7days_losers, :conditions => "users.endorsements_count > 4", :order => "users.index_7days_delta asc"  
  scope :by_30days_gainers, :conditions => "users.endorsements_count > 4", :order => "users.index_30days_delta desc"
  scope :by_30days_losers, :conditions => "users.endorsements_count > 4", :order => "users.index_30days_delta asc"  

  scope :item_limit, lambda{|limit| {:limit=>limit}}
  scope :all_endorsers_and_opposers_for_idea, lambda { |idea_id| User.joins(:endorsements).where(endorsements: {idea_id: idea_id}); }

  has_and_belongs_to_many :groups

  belongs_to :picture
  has_attached_file :buddy_icon, :styles => { :icon_24 => "24x24#", :icon_35 => "35x35#", :icon_48 => "48x48#", :icon_96 => "96x96#" }
  
  validates_attachment_size :buddy_icon, :less_than => 5.megabytes
  validates_attachment_content_type :buddy_icon, :content_type => ['image/jpeg', 'image/png', 'image/gif','image/x-png','image/pjpeg']
  
  belongs_to :sub_instance
  belongs_to :referral, :class_name => "User", :foreign_key => "referral_id"
  belongs_to :sub_instance_referral, :class_name => "SubInstance", :foreign_key => "sub_instance_referral_id"
  belongs_to :top_endorsement, :class_name => "Endorsement", :foreign_key => "top_endorsement_id", :include => :idea

  has_one :profile, :dependent => :destroy

  has_many :unsubscribes, :dependent => :destroy
  has_many :signups
  has_many :sub_instances, :through => :signups
    
  has_many :endorsements, :dependent => :destroy
  has_many :ideas, :conditions => "endorsements.status = 'active'", :through => :endorsements
  has_many :finished_ideas, :conditions => "endorsements.status = 'finished'", :through => :endorsements, :source => :idea
    
  has_many :created_ideas, :class_name => "Idea"
  
  has_many :activities, :dependent => :destroy
  has_many :points, :dependent => :destroy
  has_many :point_revisions, :class_name => "Revision", :dependent => :destroy
  has_many :rankings, :class_name => "UserRanking", :dependent => :destroy
    
  has_many :point_qualities, :dependent => :destroy

  has_many :votes, :dependent => :destroy

  has_many :comments, :dependent => :destroy
  has_many :blasts, :dependent => :destroy
  has_many :ads, :dependent => :destroy
  has_many :shown_ads, :dependent => :destroy
  has_many :charts, :class_name => "UserChart", :dependent => :destroy
  has_many :contacts, :class_name => "UserContact", :dependent => :destroy  

  has_many :sent_messages, :foreign_key => "sender_id", :class_name => "Message"
  has_many :received_messages, :foreign_key => "recipient_id", :class_name => "Message"

  has_many :sent_capitals, :foreign_key => "sender_id", :class_name => "Capital"
  has_many :received_capitals, :foreign_key => "recipient_id", :class_name => "Capital"
  has_many :capitals, :as => :capitalizable, :dependent => :nullify # this is for capitals about them, not capital they've given or received

  has_many :sent_notifications, :foreign_key => "sender_id", :class_name => "Notification"
  has_many :received_notifications, :foreign_key => "recipient_id", :class_name => "Notification"
  has_many :notifications, :as => :notifiable, :dependent => :nullify # this is for notificiations about them, not notifications they've given or received
  
  has_many :followings
  has_many :followers, :foreign_key => "other_user_id", :class_name => "Following"
  
  has_many :following_discussions, :dependent => :destroy
  has_many :following_discussion_activities, :through => :following_discussions, :source => :activity

  validates_presence_of     :login, :message => tr("Please specify a name to be identified as on the site.", "model/user")
  validates_length_of       :login, :within => 3..60
  validates_presence_of     :first_name, :message => tr("Please specify your first name.", "model/user")
  validates_presence_of     :last_name, :message => tr("Please specify your first name.", "model/user")
  
  validates_presence_of     :email, :unless => [:has_facebook?, :has_twitter?]
  validates_length_of       :email, :within => 3..100, :allow_nil => true, :allow_blank => true
  validates_uniqueness_of   :email, :case_sensitive => false, :allow_nil => true, :allow_blank => true
  validates_uniqueness_of   :facebook_uid, :allow_nil => true, :allow_blank => true
  validates_format_of       :email, :with => /^[-^!$#%&'*+\/=3D?`{|}~.\w]+@[a-zA-Z0-9]([-a-zA-Z0-9]*[a-zA-Z0-9])*(\.[a-zA-Z0-9]([-a-zA-Z0-9]*[a-zA-Z0-9])*)+$/x, :allow_nil => true, :allow_blank => true
    
  validates_presence_of     :password, :if => [:should_validate_password?]
  validates_presence_of     :password_confirmation, :if => [:should_validate_password?]
  validates_length_of       :password, :within => 4..40, :if => [:should_validate_password?]
  validates_confirmation_of :password, :if => [:should_validate_password?]

  #validates_presence_of     :post_code, :message => tr("Please enter your postcode.", "model/user")
  #validates_presence_of     :age_group, :message => tr("Please select your age group.", "model/user")
  #validates_presence_of     :my_gender, :message => tr("Please select your gender.", "model/user")

  validates_acceptance_of   :terms, :message => tr("Please accept the terms and conditions", "model/user")

 # validates_inclusion_of    :age_group, :in => lambda {|foo| foo.allowed_for_age_group},
 #                           message: tr("Please select your gender.", "model/user")
 # validates_inclusion_of    :my_gender, :in => lambda {|foo| foo.allowed_for_gender}, message: tr("Please select your gender.", "model/user")

  #validate :validate_age_group
  #validate :validate_gender

  before_save :encrypt_password
  before_create :make_rss_code
  after_save :update_signups
  after_create :check_contacts
  after_create :give_sub_instance_credit
  after_create :give_user_credit
  after_create :new_user_signedup
  after_create :set_signup_country
  
  attr_protected :remember_token, :remember_token_expired_at, :activation_code, :salt, :crypted_password, :twitter_token, :twitter_secret
  
  # Virtual attribute for the unencrypted password
  attr_accessor :password, :sub_instance_ids, :terms


  def validate_age_group
    unless allowed_for_age_group.include?(self.age_group)
      self.errors.add(:age_group ,tr("Please select your age group", "model/user"))
    end
  end

  def validate_gender
    unless allowed_for_gender.include?(self.my_gender)
      self.errors.add(:my_gender ,tr("Please select gender", "model/user"))
    end
  end

  def allowed_for_age_group
    [tr("12 years and younger", "model/user"),tr("13 to 17 years", "model/user"),tr("18 to 25 years", "model/user"),tr("26 to 69 years", "model/user"),tr("70 years and older", "model/user")]
  end

  def allowed_for_gender
    [tr("Male", "model/user"),tr("Female", "model/user")]
  end

  def set_signup_country
    self.geoblocking_open_countries=Thread.current[:country_code] if Thread.current[:country_code]
  end
  
  def gender
    tr('unknown','')
  end
  
  def guest?
    false
  end
  
  def needs_activation?
    if self.status == "active"
      false
    elsif self.facebook_uid or self.identifier_url
      false
    else
      true
    end
  end

  def geoblocking_disabled_for?(sub_instance)
    self.geoblocking_open_countries.split.each do |user_country|
      sub_instance.geoblocking_open_countries.split.each do |sub_instance_country|
        return true if user_country == sub_instance_country
      end
    end
    return false
  end
  
  def new_user_signedup
    ActivityUserNew.create(:user => self, :sub_instance => sub_instance)
    resend_activation if self.has_email? and self.is_pending? # and not self.identifier_url
  end

  def check_contacts
    if self.has_email?
      existing_contacts = UserContact.find(:all, :conditions => ["email = ? and other_user_id is null",email], :order => "created_at asc")
      for c in existing_contacts
        if c.is_invited? # they were invited by this person
          c.accept!
        else # they're in the contacts, but not invited by this person
           c.update_attribute(:other_user_id,self.id)
           notifications << NotificationContactJoined.new(:sender => self, :recipient => c.user)
           c.user.increment!(:contacts_members_count)
           c.user.decrement!(:contacts_not_invited_count)         
        end
      end
    end
    if self.has_facebook?
      existing_contacts = UserContact.find(:all, :conditions => ["facebook_uid = ? and other_user_id is null",self.facebook_uid], :order => "created_at asc")
      for c in existing_contacts
        if c.is_invited? # they were invited by this person
          c.accept!
        else
          c.update_attribute(:other_user_id,self.id)
        end
      end    
    end
  end
  
  def should_validate_password?
    return false if has_twitter? or has_facebook? or not new_record?
    return true
  end
  
  def give_sub_instance_credit
    return unless sub_instance_referral
#    ActivityPartnerUserRecruited.create(:user => sub_instance_referral.owner, :other_user => self, :sub_instance => sub_instance_referral)
#    ActivityCapitalPartnerUserRecruited.create(:user => sub_instance_referral.owner, :other_user => self, :sub_instance => sub_instance_referral, :capital => CapitalPartnerUserRecruited.create(:recipient => sub_instance_referral.owner, :amount => 2, :capitalizable => self))
#    sub_instance_referral.owner.increment!(:referrals_count)
  end
  
  def give_user_credit
    return unless referral
    ActivityInvitationAccepted.create(:other_user => referral, :user => self)
    ActivityUserRecruited.create(:user => referral, :other_user => self, :is_user_only => true) 
    referral.increment!(:referrals_count)
  end  
  
  def update_signups
    unless sub_instance_ids.nil?
      self.signups.each do |s|
        s.destroy unless sub_instance_ids.include?(s.sub_instance_id.to_s)
        sub_instance_ids.delete(s.sub_instance_id.to_s)
      end 
      sub_instance_ids.each do |p|
        self.signups.create(:sub_instance_id => p) unless p.blank?
      end
      reload
      self.sub_instance_ids = nil
    end
  end

  after_create :on_pending_entry

  include Workflow
  workflow_column :status
  workflow do
    state :pending do
      event :activate, transitions_to: :active
      event :suspend, transitions_to: :suspended
      event :remove, transitions_to: :removed
      event :probation, transitions_to: :probation
    end
    state :passive do
      event :register, transitions_to: :pending, meta: { validates_presence_of: [:crypted_password, :password] }
      event :activate, transitions_to: :active
      event :suspend, transitions_to: :suspended
      event :remove, transitions_to: :removed
      event :probation, transitions_to: :probation
    end
    state :active do
      event :suspend, transitions_to: :suspended
      event :remove, transitions_to: :removed
      event :probation, transitions_to: :probation
    end
    state :suspended do
      event :remove, transitions_to: :removed
      event :unsuspend, transitions_to: :active, meta: { validates_presence_of: [:activated_at] }
      event :unsuspend, transitions_to: :pending, meta: { validates_presence_of: [:activation_code] }
      event :unsuspend, transitions_to: :passive
    end
    state :probation do
      event :suspend, transitions_to: :suspended
      event :remove, transitions_to: :removed
      event :unprobation, transitions_to: :active, meta: { validates_presence_of: [:activated_at] }
      event :unprobation, transitions_to: :pending, meta: { validates_presence_of: [:activation_code] }
      event :unprobation, transitions_to: :passive
    end
    state :removed
  end

   def on_pending_entry(new_state = nil, event = nil)
    self.probation_at = nil
    self.suspended_at = nil
    self.removed_at = nil
    save(:validate => false) if persisted?
  end

  # Activates the user in the database.
  def on_active_entry(new_state, event)
    @activated = true
    self.activated_at ||= Time.now.utc
    self.activation_code = nil
    self.probation_at = nil
    self.suspended_at = nil
    self.removed_at = nil
    for e in endorsements.suspended
      e.unsuspend!
    end
    self.warnings_count = 0
    save(:validate => false)
  end  
  
  def on_removed_entry(new_state, event)
    self.removed_at = Time.now
    for e in endorsements
      e.destroy
    end    
    for f in followings
      f.destroy
    end
    for f in followers
      f.destroy
    end 
    for c in received_capitals
      c.destroy
    end
    for c in sent_capitals
      c.destroy
    end
    #for c in constituents
    #  c.destroy
    #end
    self.facebook_uid = nil
    save(:validate => false)
  end
  
  def on_probation_entry(new_state, event)
    self.probation_at = Time.now
    save(:validate => false)
    ActivityUserProbation.create(:user => self)
  end
  
  def on_suspended_entry(new_state, event)
    self.suspended_at = Time.now
    for e in endorsements.active
      e.suspend!
    end
    save(:validate => false)
  end  
  
  def resend_activation
    make_activation_code
    UserMailer.welcome(self).deliver
  end
  
  def send_welcome
    unless self.have_sent_welcome
      UserMailer.welcome(self).deliver    
    end
  end

  def to_param
    "#{id}-#{login.parameterize_full}"
  end  
  
  cattr_reader :per_page
  @@per_page = 25  
  
  def request=(request)
    if request
      self.ip_address = request.remote_ip
      self.user_agent = request.env['HTTP_USER_AGENT']
      self.referrer = request.env['HTTP_REFERER']
    end
  end  
  
  def is_subscribed=(value)
    if not value
      self.report_frequency = 0
      self.is_comments_subscribed = false
      self.is_votes_subscribed = false
      self.is_point_changes_subscribed = false      
      self.is_followers_subscribed = false
      self.is_finished_subscribed = false      
      self.is_messages_subscribed = false
      self.is_votes_subscribed = false
      self.is_admin_subscribed = false
    else
      self.report_frequency = 0
      self.is_comments_subscribed = true
      self.is_votes_subscribed = true     
      self.is_point_changes_subscribed = true
      self.is_followers_subscribed = true 
      self.is_finished_subscribed = true           
      self.is_messages_subscribed = true
      self.is_votes_subscribed = true
      self.is_admin_subscribed = true
    end
  end
  
  def update_counts
    self.endorsements_count = endorsements.active.size
    self.up_endorsements_count = endorsements.active.endorsing.size
    self.down_endorsements_count = endorsements.active.opposing.size
    self.comments_count = comments.size
    self.point_revisions_count = point_revisions.published.size
    self.points_count = points.published.size
    self.qualities_count = point_qualities.size
    return true
  end
  
  def to_param_link
    user_path(self)
  end
  
  def has_top_idea?
    attribute_present?("top_endorsement_id") and top_endorsement
  end

  def most_recent_activity
    @most_recent_activity ||= activities.active.by_recently_created.find(:all, :limit => 1)[0]
  end  

  def idea_list
    @idea_list ||= begin
      s = tr("My top ideas","user")
      row = 0
      for e in endorsements
        row=row+1
        s += "\r\n" + row.to_s + ". " + e.idea.name if row < 11
      end
      s
    end
  end
    
  # ranking metrics
  def up_issue_diversity
    return 0 if up_endorsements_count < 5 or not Instance.current.is_tags?
    up_issues_count.to_f/up_endorsements_count.to_f
  end

  def recent_login?
    return false if loggedin_at.nil?
    loggedin_at > Time.now-30.days
  end

  def calculate_score
    count = 0.1
    count += 1 #if active?
    count += 3 if recent_login?
    count += 0.5 if points_count > 0
    count += up_issue_diversity
    #count += 0.6 if constituents_count > 1
    count = count/6
    count = 1 if count > 1
    count = 0.1 if count < 0.1
    return count
  end
  
  def activity_rank
    (score*10).to_i
  end 
  
  def quality_factor
    # TODO: this needs to me rethought, since it penalizes users for rating points
    return 1 #if qualities_count < 10
    rev_count = point_revisions_count
    return 10/qualities_count.to_f if rev_count == 0
    i = (rev_count*2).to_f/qualities_count.to_f
    return 1 if i > 1
    return i
  end
  
  def address_full
    a = ""
    a += address + ", " if attribute_present?("address")
    a += city + ", " if attribute_present?("city")
    a += state + ", " if attribute_present?("state")
    a += zip if attribute_present?("zip")
    a
  end
   
  def revisions_count
    @revision_count ||= point_revisions_count-points_count
  end
  
  def pick_ad(current_idea_ids)
  	shown = 0
  	for ad in Ad.active.most_paid.all
  		if shown == 0 and not current_idea_ids.include?(ad.idea_id)
  			shown_ad = ad.shown_ads.find_by_user_id(self.id)
  			if shown_ad and not shown_ad.has_response? and shown_ad.seen_count < 4
  				shown_ad.increment!(:seen_count)
  				return ad
  			elsif not shown_ad
  				shown_ad = ad.shown_ads.create(:user => self)
  				return ad
  			end
  		end
  	end    
  	return nil
  end
  
  def following_user_ids
    @following_user_ids ||= followings.collect{|f|f.other_user_id}
  end
  
  def follower_user_ids
    @follower_user_ids ||= followers.collect{|f|f.user_id}
  end
  
  def calculate_contacts_count
    self.contacts_members_count = contacts.active.members.not_following.size
    self.contacts_invited_count = contacts.active.not_members.invited.size
    self.contacts_not_invited_count = contacts.active.not_members.not_invited.size
    self.contacts_count = contacts.active.size
  end

  def expire_charts
    Rails.cache.delete("views/user_idea_chart_official-#{self.id.to_s}-#{self.endorsements_count.to_s}")
    Rails.cache.delete("views/user_idea_chart-#{self.id.to_s}-#{self.endorsements_count.to_s}")
  end
  
  def recommend(limit=10)
    return [] unless self.endorsements_count > 0
    @recommend ||= begin
      sql = "select relationships.percentage, ideas.id
      from relationships,ideas
      where relationships.other_idea_id = ideas.id and ("
      if up_endorsements_count > 0
        sql += "(relationships.idea_id in (#{endorsements.active_and_inactive.endorsing.collect{|e|e.idea_id}.join(',')}) and relationships.type = 'RelationshipEndorserEndorsed')"
      end
      if up_endorsements_count > 0 and down_endorsements_count > 0
        sql += " or "
      end
      if down_endorsements_count > 0
        sql += "(relationships.idea_id in (#{endorsements.active_and_inactive.opposing.collect{|e|e.idea_id}.join(',')}) and relationships.type = 'RelationshipOpposerEndorsed')"
      end
      sql += ") and relationships.other_idea_id not in (select idea_id from endorsements where user_id = " + self.id.to_s + ")
      and ideas.position > 25
      and ideas.status = 'published'
      group by ideas.id, relationships.percentage
      order by relationships.percentage desc"
      sql += " limit " + limit.to_s
      
      idea_ids = Idea.find_by_sql(sql).collect{|p|p.id}
      Idea.find(idea_ids).paginate :per_page => limit, :page => 1
    end
  end

  # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
  def self.authenticate(email, password)
    u = find :first, :conditions => ["email = ? and status in ('active','pending')", email] # need to get the salt
    if u && u.authenticated?(password) 
      #u.update_attribute(:loggedin_at,Time.now)
      return u
    else
      return nil
    end
  end

  # Encrypts some data with the salt.
  def self.encrypt(password, salt)
    Digest::SHA1.hexdigest("--#{salt}--#{password}--")
  end

  # Encrypts the password with the user salt
  def encrypt(password)
    self.class.encrypt(password, salt)
  end

  def authenticated?(password)
    crypted_password == encrypt(password)
  end

  def remember_token?
    remember_token_expires_at && Time.now.utc < remember_token_expires_at 
  end

  # These create and unset the fields required for remembering users between browser closes
  def remember_me
    remember_me_for 4.weeks
  end

  def remember_me_for(time)
    remember_me_until time.from_now.utc
  end

  def remember_me_until(time)
    self.remember_token_expires_at = time
    self.remember_token            = encrypt("#{email}--#{remember_token_expires_at}")
    save(:validate => false)
  end

  def forget_me
    self.remember_token_expires_at = nil
    self.remember_token            = nil
    save(:validate => false)
  end

  def name
    return login
  end
  
  def real_name
    return login if not attribute_present?("first_name") or not attribute_present?("last_name")
    n = first_name + ' ' + last_name
    n
  end
  
  def is_sub_instance?
    attribute_present?("sub_instance_id")
  end
  
  def is_new?
    created_at > Time.now-(86400*7)
  end
  
  def is_influential?
    return false if position == 0
    position < Endorsement.max_position 
  end
  
  # Returns true if the user has just been activated.
  def recently_activated?
    @activated
  end

  def active?
    # the existence of an activation code means they have not activated yet
    activation_code.nil?
  end

  def activated?
    active?
  end
  
  def is_active?
    ['pending','active'].include?(status)
  end

  def is_suspended?
    ['suspended'].include?(status)
  end

  def is_pending?
    status == 'pending'
  end  
  
  def is_ambassador?
    contacts_invited_count > 0    
  end
  
  def has_picture?
#    attribute_present?("picture_id") or attribute_present?("buddy_icon_file_name") 
    attribute_present?("buddy_icon_file_name") 
  end
  
  def has_referral?
    attribute_present?("referral_id")
  end
  
  def has_sub_instance_referral?
    attribute_present?("sub_instance_referral_id") and sub_instance_referral_id != 1
  end  
  
  def has_twitter?
    attribute_present?("twitter_token")
  end

  def has_website?
    attribute_present?("website")
  end
  
  def has_zip?
    attribute_present?("zip")
  end  
  
  def website_link
    return nil if self.website.nil?
    wu = website
    wu = 'http://' + wu if wu[0..3] != 'http'
    return wu    
  end  

  def capital_received
    Capital.sum(:amount, :conditions => ["recipient_id = ?",id])    
  end

  def capital_spent
    Capital.sum(:amount, :conditions => ["sender_id = ?",id])
  end
  
  def inactivity_capital_lost
    Capital.sum(:amount, :conditions => ["recipient_id = ? and type='CapitalInactive'",id]) 
  end
  
  def has_capital?
    capitals_count != 0
  end

  def has_google_token?
    attribute_present?("google_token")
  end
  
  def update_capital
    new_capitals_count = capital_received-capital_spent
    capitals_difference = new_capitals_count - self.capitals_count
    self.update_attribute(:capitals_count,new_capitals_count)

    if capitals_difference != 0 and !self.is_admin and self.is_capital_subscribed and self.status == "active"
      User.delay.send_capital_email(self.activities.last.id, capitals_difference)
    end
  end  
  
  def follow(u)
    return nil if u.id == self.id
    f = followings.find_by_other_user_id(u.id)
    return f if f and f.value == 1
    unignore(u) if f and f.value == -1
    following = followings.create(:other_user => u, :value => 1)
    contact_exists = contacts.find_by_other_user_id(u.id)
    if contact_exists
      contact_exists.update_attribute(:following_id, following.id)
      self.decrement!(:contacts_members_count)        
    end
    return following
  end
  
  def unfollow(u)
    f = followings.find_by_other_user_id_and_value(u.id,1)
    f.destroy if f
    contact_exists = contacts.find_by_other_user_id(u.id)
    if contact_exists
      contact_exists.update_attribute(:following_id, nil)
      self.increment!(:contacts_members_count)        
    end     
  end
  
  def ignore(u)
    f = followings.find_by_other_user_id(u.id)
    return f if f and f.value == -1
    unfollow(u) if f and f.value == 1
    followings.create(:other_user => u, :value => -1)    
  end
  
  def unignore(u)
    f = followings.find_by_other_user_id_and_value(u.id,-1)
    f.destroy if f
  end
  
  def reset_password
    new_password = random_password
    self.update_attribute(:password, new_password)
    UserMailer.new_password(self, new_password).deliver
  end
  
  def random_password( size = 4 )
    c = %w(b c d f g h j k l m n p qu r s t v w x z ch cr fr nd ng nk nt ph pr rd sh sl sp st th tr lt)
    v = %w(a e i o u y)
    f, r = true, ''
    (4 * 2).times do
      r << (f ? c[rand * c.size] : v[rand * v.size])
      f = !f
    end
    r    
  end
  
  def index_charts(limit=30)
    @index_charts ||= IdeaChart.find_by_sql(["select idea_charts.date_year,idea_charts.date_month,idea_charts.date_day,
    sum(idea_charts.volume_count) as volume_count,
    sum((idea_charts.down_count*(endorsements.value*-1))+(idea_charts.up_count*endorsements.value)) as down_count,
    avg(endorsements.value*idea_charts.change_percent) as percentage
    from idea_charts, endorsements
    where endorsements.user_id = ? and endorsements.status = 'active'
    and endorsements.idea_id = idea_charts.idea_id
    group by endorsements.user_id, idea_charts.date_year, idea_charts.date_month, idea_charts.date_day
    order by idea_charts.date_year desc, idea_charts.date_month desc, idea_charts.date_day desc limit ?",id,limit])
  end
  
  # computes the change in percentage of all their ideas over the last [limit] days.
  def index_delta_percent(limit=7)
    index_charts(limit-1).collect{|c|c.percentage.to_f}.reverse.sum
  end
  
  def index_chart_hash(limit=30)
    h = Hash.new
    h[:charts] = index_charts(limit)
    h[:volume_counts] = h[:charts].collect{|c| c.volume_count.to_i}.reverse
    h[:max_volume] = h[:volume_counts].max
    h[:percentages] = h[:charts].collect{|c|c.percentage.to_f}.reverse
    h[:percentages][0] = 0
    for i in 1..h[:percentages].length-1
    	 h[:percentages][i] =  h[:percentages][i-1] + h[:percentages][i]
    end
    h[:max_percentage] = h[:percentages].max.abs
    if h[:max_percentage] < h[:percentages].min.abs
      h[:max_percentage] = h[:percentages].min.abs
    end
    h[:adjusted_percentages] = []
    for i in 0..h[:percentages].length-1
      h[:adjusted_percentages][i] = h[:percentages][i] + h[:max_percentage]
    end
    return h
  end
  
  def index_chart_with_official_hash(limit=30)
    h = Hash.new
    h[:charts] = index_charts(limit)
    h[:official_charts] = Instance.current.official_user.index_charts(limit)
    h[:percentages] = h[:charts].collect{|c|c.percentage.to_f}.reverse
    h[:percentages][0] = 0
    for i in 1..h[:percentages].length-1
    	 h[:percentages][i] =  h[:percentages][i-1] + h[:percentages][i]
    end
    h[:official_percentages] = h[:official_charts].collect{|c|c.percentage.to_f}.reverse
    h[:official_percentages][0] = 0
    for i in 1..h[:official_percentages].length-1
    	 h[:official_percentages][i] = h[:official_percentages][i-1] + h[:official_percentages][i]
    end
    
    h[:max_percentage] = h[:percentages].max.abs
    if h[:max_percentage] < h[:percentages].min.abs
      h[:max_percentage] = h[:percentages].min.abs
    end
    if h[:max_percentage] < h[:official_percentages].max.abs
      h[:max_percentage] = h[:official_percentages].max.abs
    end
    if h[:max_percentage] < h[:official_percentages].min.abs
      h[:max_percentage] = h[:official_percentages].min.abs
    end
        
    h[:adjusted_percentages] = []
    for i in 0..h[:percentages].length-1
      h[:adjusted_percentages][i] = h[:percentages][i] + h[:max_percentage]
    end
    h[:official_adjusted_percentages] = []
    for i in 0..h[:official_percentages].length-1
      h[:official_adjusted_percentages][i] = h[:official_percentages][i] + h[:max_percentage]
    end    
    return h
  end  
  
  def has_facebook?
    self.attribute_present?("facebook_uid")
  end
  
  def has_email?
    self.attribute_present?("email")
  end  
  
  def create_first_and_last_name_from_name(s)
    names = s.split
    self.last_name = names.pop
    self.first_name = names.join(' ')
  end
  
  def access_token
    self.twitter_token
  end

  def access_secret
    self.twitter_secret
  end
  
  #if TwitterAuth.oauth?
  #  include TwitterAuth::OauthUser
  #else
  #   include TwitterAuth::BasicUser
  #end

  def twitter
    if TwitterAuth.oauth?
      TwitterAuth::Dispatcher::Oauth.new(self)
    else
      TwitterAuth::Dispatcher::Basic.new(self)
    end
  end

  def twitter_followers_count
    return 0 unless attribute_present?("twitter_token")
    twitter.get('/users/'+twitter_id.to_s)['followers_count']
  end  
  
  # this can be run on a regular basis
  # it will look up all the people this person is following on twitter, and follow them here
  # this only works for the first 5000 followers, need to support new cursor format to do more
  def follow_twitter_friends
    count = 0
    friend_ids = twitter.get('/friends/ids.json?id='+twitter_id.to_s)
    Rails.logger.debug("follow_twitter_friends #{friend_ids.count} friends")
    if friend_ids.any?
      if following_user_ids.any?
        users = User.active.find(:all, :conditions => ["twitter_id in (?) and id not in (?)",friend_ids, following_user_ids])
      else
        users = User.active.find(:all, :conditions => ["twitter_id in (?)",friend_ids])
      end
      for user in users
        count += 1
        follow(user)
      end
    end
    return count
  end  
  
  # this is for when someone adds twitter to their account for the first time
  # it will look up all the people who are following this person on twitter and are already members
  # and automatically follow this new person here.
  def twitter_followers_follow
    count = 0
    followers_ids = twitter.get('/followers/ids.json?id='+twitter_id.to_s)
    if follower_ids.any?
      if follower_user_ids.any?
        users = User.active.find(:all, :conditions => ["twitter_id in (?) and id not in (?)",follower_ids, follower_user_ids])
      else
        users = User.active.find(:all, :conditions => ["twitter_id in (?)",follower_ids])
      end
      for user in users
        count += 1
        user.follow(self)
      end
    end
    return count    
  end

  def User.create_from_twitter(twitter_info, token, secret, request)
    name = twitter_info['name']
    if User.find_by_login(name)
      name = twitter_info['screen_name']
      if User.find_by_login(name)
        name = name + " TW"
      end
    end
    u = User.new(:twitter_id => twitter_info['id'].to_i, :twitter_token => token, :twitter_secret => secret)
    u.login = name
    u.create_first_and_last_name_from_name(twitter_info['name'])
    u.twitter_login = twitter_info['screen_name']
    u.twitter_count = twitter_info['followers_count'].to_i
    u.website = twitter_info['url']
    u.request = request
    if twitter_info['profile_image_url']
      u.picture = Picture.create_from_url(twitter_info['profile_image_url'])
    end
    if u.save(:validate => false)
      u.activate!
      return u
    else
      return nil
    end
  end
  
  def send_report_if_needed!
    if self.reports_enabled
      if self.reports_interval and self.reports_interval==1
        interval = 1.hour
      elsif self.reports_interval and self.reports_interval==2
        interval = 1.day
      else
        interval = 7.days
      end
      if self.last_sent_report==nil or Time.now-interval>self.last_sent_report
        tags = TagSubscription.find_all_by_user_id(self.id).collect {|sub| sub.tag.name if sub.tag }.compact
        unless tags.empty?
          if self.reports_discussions
            ideas = Idea.tagged_with(tags,:match_any=>true).published.since(self.last_sent_report)
          else
            ideas = []
          end
          if not ideas.empty?
            UserMailer.report(self,ideas).deliver
          end
        end
        self.reload
        self.last_sent_report=Time.now
        self.save(:validate => false)
      end
    end
  end

  def update_with_twitter(twitter_info, token, secret, request)
    self.twitter_id = twitter_info['id'].to_i
    self.twitter_login = twitter_info['screen_name']
    self.twitter_token = token
    self.twitter_secret = secret            
    self.website = twitter_info['url'] if not self.has_website?
    if twitter_info['profile_image_url'] and not self.has_picture?
      self.picture = Picture.create_from_url(twitter_info['profile_image_url'])
    end
    self.twitter_count = twitter_info['followers_count'].to_i
    self.save(:validate => false)
    self.activate! if not self.activated?
  end  
  
  def User.create_from_facebook(facebook_user,sub_instance,request)
    name = facebook_user.name
    # check for existing account with this name
    Rails.logger.info("LOGIN: CREATE FROM FACEBOOK from #{facebook_user.inspect} UID #{facebook_user.id} Name #{facebook_user.name}")
    u = User.new(
     :login => name,
     :email => facebook_user.email,
     :first_name => facebook_user.first_name,
     :last_name => facebook_user.last_name,       
     :facebook_uid => facebook_user.id,
     :facebook_id => facebook_user.id,
     :sub_instance_referral => sub_instance,
     :request => request
    )
    Rails.logger.info("LOGIN: CREATE FROM FACEBOOK user #{u.inspect}")

    if u.save(:validate => false)
      u.activate!
      return u
    else
      Rails.logger.error "ERROR w/ user -- " + u.errors.full_messages.join(" | ")
      return nil
    end
  end
  
  def update_with_facebook(facebook_user)
    self.facebook_uid = facebook_user.id
    # need to do some checking on whether this facebook_uid is already attached to a diff account
    check_existing_facebook = User.active.find(:all, :conditions => ["facebook_uid = ? and id <> ?",self.facebook_uid,self.id])
    if check_existing_facebook.any?
      for e in check_existing_facebook
        e.remove_facebook
        e.save(:validate => false)
      end
    end
    self.save(:validate => false)
    check_contacts # looks for any contacts with the facebook uid, and connects them
    return true
  end
  
  def remove_facebook
    return unless has_facebook?
    self.facebook_uid = nil
    # i don't think this does everything necessary to zap facebook from their account
  end  
  
  def make_rss_code
    return self.rss_code if self.attribute_present?("rss_code")
    self.rss_code = Digest::SHA1.hexdigest( Time.now.to_s.split(//).sort_by {rand}.join )
  end  
  
  def root_url
    return 'http://' + Instance.current.base_url_w_sub_instance + '/'
  end
  
  def profile_url
    'http://' + Instance.current.base_url_w_sub_instance + '/users/' + to_param
  end
  
  def unsubscribe_url
    'http://' + Instance.current.base_url_w_sub_instance + '/unsubscribes/new'
  end
  
  def self.adapter
    return 'mysql'
  end
  
  def do_abusive!(parent_notifications)
     if self.warnings_count == 0 # this is their first warning, get a warning message
      parent_notifications << NotificationWarning1.new(:recipient => self)
    elsif self.warnings_count == 1 # 2nd warning
      parent_notifications << NotificationWarning2.new(:recipient => self)
    elsif self.warnings_count == 2 # third warning, on probation
      parent_notifications << NotificationWarning3.new(:recipient => self)      
      self.probation!
    elsif self.warnings_count >= 3 # fourth or more warning, suspended
      parent_notifications << NotificationWarning4.new(:recipient => self)      
      self.suspend!
    end
    self.increment!("warnings_count")
  end

  def self.send_capital_email(activity_id, point_difference)
    activity = Activity.find(activity_id)
    user = activity.user
    UserMailer.lost_or_gained_capital(user, activity, point_difference).deliver
  end

  def self.send_status_email(idea_id, status, date, subject, message)
    status_types = {
      '-2' => tr("Failed","status_messages"),
      '-1' => tr("In Progress","status_messages"),
       '0' => tr("Published","status_messages"),
       '2' => tr("Successful","status_messages")
    }
    status = status_types[status]
    idea = Idea.find(idea_id)
    all_endorsers_and_opposers_for_idea(idea_id).each do |user|
      next unless user.is_finished_subscribed
      position = Endorsement.where(idea_id: idea_id, user_id: user.id).first.value
      UserMailer.idea_status_update(idea, status, date, subject, message, user, position).deliver
    end
  end

  def self.send_report_emails(frequency)
    top_ideas = {}
    idea_followers = {}
    top_category_score = {}
    Category.all.each do |category|
      category = Tag.find_by_name(category.name)
      top_ideas[category] = Idea.tagged_with(category, :on => :issues).published.top_rank.limit(3)
      top_category_score[category] = top_ideas[category].shift.score
      top_ideas[category].each do |idea|
        idea_followers[idea.id] = all_endorsers_and_opposers_for_idea(idea.id).collect { |u| u.id }
      end
    end

    User.where("status = 'active' AND report_frequency = ? AND is_admin = 0", frequency).each do |user|
      # the user's top 5 ranked ideas
      important = user.endorsements.active.by_position.limit(5).collect { |e| Idea.find(e.idea) }
      next if important.empty?

      # ideas in 2nd/3rd place which the user has not endorsed/opposed,
      # but at least a quarter of his/her followers has
      important_to_followers = []

      # ideas the user has endorsed/opposed which are in 2nd or 3rd
      # place in a category
      near_top = []

      top_ideas.each do |category, ideas|
        ideas.each_with_index do |idea, index|
          follower_count = user.followers.count
          if idea_followers[idea.id].include?(user.id)
            position = Endorsement.find(:first, conditions: { user_id: user.id, idea_id: idea.id }).value
            near_top << {
                idea: idea,
                position: index+2,
                category: category,
                endorsement: position,
                distance: top_category_score[category] - idea.score,
            }
          else
            follower_endorsements = Endorsement.find(:all, conditions: ["idea_id = ? AND user_id IN (?)", idea.id, user.follower_ids]).count
            if follower_endorsements > follower_count / 10
              important_to_followers << { idea: idea, position: index+2, category: category, follower_endorsements: follower_endorsements }
            end
          end
        end
      end

      # only retain at most 3 which have the most support from the user's followers
      important_to_followers.sort! { |x,y| x[:follower_endorsements] <=> y[:follower_endorsements] }
      important_to_followers = important_to_followers[0..2] if important_to_followers.count > 3

      # only retain at most 3 which are closest to being in 1st place in a category
      near_top.sort! { |x,y| x[:distance] <=> y[:distance] }
      near_top = near_top[0..2] if near_top.count > 3

      UserMailer.user_report(user, important, important_to_followers, near_top, frequency).deliver
    end
  end

  def is_group_admin?(idea)
    return true if self.is_admin?
    groups_user = idea ? GroupsUser.where(:user_id=>self.id, :group_id=>idea.group_id) : nil
    if groups_user and groups_user.is_admin?
      true
    else
      false
    end
  end

  protected
  
    # before filter 
    def encrypt_password
      return if password.blank?
      self.salt = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{login}--") if new_record?
      self.crypted_password = encrypt(password)
    end
      
    def password_required?
      !password.blank?
    end
    
    def make_activation_code
      self.update_attribute(:activation_code,Digest::SHA1.hexdigest( Time.now.to_s.split(//).sort_by {rand}.join ))
    end
    
end
