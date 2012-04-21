class Instance < ActiveRecord::Base

  require 'paperclip'
  
  scope :active, :conditions => "status = 'active'"
  scope :pending, :conditions => "status = 'pending'"
  scope :least_active, :conditions => "status = 'active'", :order => "users_count"
  scope :facebook, :conditions => "is_facebook = true"
  scope :twitter, :conditions => "is_twitter = true"
  
  belongs_to :official_user, :class_name => "User"
  belongs_to :color_scheme
  
  belongs_to :picture
  
  has_attached_file :logo, :styles => { :icon_96 => "96x96#", :icon_140  => "140x140#", :icon_180 => "180x180#", :medium => "450x" }
  
  validates_attachment_size :logo, :less_than => 5.megabytes
  validates_attachment_content_type :logo, :content_type => ['image/jpeg', 'image/png', 'image/gif']
    
  belongs_to :buddy_icon_old, :class_name => "Picture"
  has_attached_file :buddy_icon, :styles => { :icon_24 => "24x24#", :icon_48  => "48x48#", :icon_96 => "96x96#" }
    
  validates_attachment_size :buddy_icon, :less_than => 5.megabytes
  validates_attachment_content_type :buddy_icon, :content_type => ['image/jpeg', 'image/png', 'image/gif']    
      
  belongs_to :fav_icon_old, :class_name => "Picture"
  has_attached_file :fav_icon, :styles => { :icon_16 => "16x16#" }
  
  validates_attachment_size :fav_icon, :less_than => 5.megabytes
  validates_attachment_content_type :fav_icon, :content_type => ['image/jpeg', 'image/png', 'image/gif']  
  
  validates_presence_of     :name
  validates_length_of       :name, :within => 3..60

  validates_presence_of     :admin_name
  validates_length_of       :admin_name, :within => 3..60

  validates_presence_of     :admin_email
  validates_length_of       :admin_email, :within => 3..100, :allow_nil => true, :allow_blank => true
  validates_format_of       :admin_email, :with => /^[-^!$#%&'*+\/=3D?`{|}~.\w]+@[a-zA-Z0-9]([-a-zA-Z0-9]*[a-zA-Z0-9])*(\.[a-zA-Z0-9]([-a-zA-Z0-9]*[a-zA-Z0-9])*)+$/x

#  validates_presence_of     :email
#  validates_length_of       :email, :within => 3..100, :allow_nil => true, :allow_blank => true
#  validates_format_of       :email, :with => /^[-^!$#%&'*+\/=3D?`{|}~.\w]+@[a-zA-Z0-9]([-a-zA-Z0-9]*[a-zA-Z0-9])*(\.[a-zA-Z0-9]([-a-zA-Z0-9]*[a-zA-Z0-9])*)+$/x

  validates_presence_of     :tags_name
  validates_length_of       :tags_name, :maximum => 20
  validates_presence_of     :currency_name
  validates_length_of       :currency_name, :maximum => 30
  validates_presence_of     :currency_short_name
  validates_length_of       :currency_short_name, :maximum => 3
  
 # validates_inclusion_of    :homepage, :in => Homepage::NAMES.collect{|n|n[0]}
  validates_inclusion_of    :tags_page, :in => Homepage::TAGS.collect{|n|n[0]}
  
  after_save :clear_cache
  before_save :last_minute_checks
  
  def last_minute_checks
    self.homepage = 'top' if not self.is_tags? and self.homepage == 'index'
  end

  def clear_cache
    Rails.cache.delete('instance')
    return true
  end
  
  def self.current  
    Thread.current[:instance]
  end  
  
  def self.current=(instance)
    raise(ArgumentError,"Invalid instance. Expected an object of class 'Instance', got #{instance.inspect}") unless instance.is_a?(Instance)
    Thread.current[:instance] = instance
  end
  
  def base_url
    self.domain_name
  end

  def base_url_w_sub_instance
    if SubInstance.current
      SubInstance.current.short_name + '.' + self.domain_name
    else
      self.domain_name
    end
  end
  
  def homepage_url(sub_instance=nil)
    if Thread.current[:localhost_override]
      'http://' + Thread.current[:localhost_override] + '/'
    else
      if p = sub_instance or p = SubInstance.current
        'http://' + p.short_name + '.' + base_url + '/'
      else
        'http://' + base_url + '/'
      end
    end
  end
  
  def name_with_tagline
    return name unless attribute_present?("tagline")
    name + ": " + tagline
  end
  
  def update_counts
    self.users_count = User.count
    self.ideas_count = Idea.published.filtered.count
    self.endorsements_count = Endorsement.active_and_inactive.count
    self.sub_instances_count = SubInstance.active.count
    self.points_count = Point.published.count
    self.contributors_count = User.active.at_least_one_endorsement.contributed.count
    self.save(:validate => false)
  end  
  
  def has_official?
    false
    #attribute_present?("official_user_id")
  end

  def official_user_name
    official_user.name if official_user
  end
  
  def official_user_name=(n)
    self.official_user = User.find_by_login(n) unless n.blank?
  end  
  
  def has_google_analytics?
    attribute_present?("google_analytics_code")
  end
  
  def has_twitter_enabled?
    return false unless is_twitter?
    return true if attribute_present?("twitter_key") and attribute_present?("twitter_secret_key")
  end
  
  def has_facebook_enabled?
    return false unless is_facebook?
    return true
  end
  
  def has_windows_enabled?
    self.attribute_present?("windows_appid")
  end
  
  def has_yahoo_enabled?
    self.attribute_present?("yahoo_appid")
  end
  
  # this will go away when full migrated to paperclip
  def has_picture?
    attribute_present?("picture_id")
  end
  
  def has_fav_icon?
    attribute_present?("fav_icon_file_name")
  end
  
  def has_buddy_icon?
    attribute_present?("buddy_icon_file_name")
  end
  
  def has_logo?
    attribute_present?("logo_file_name")
  end
  
  def is_searchable?
    not ENV["WEBSOLR_URL"].nil?
  end

  def logo_large
    return nil unless has_logo?
    '<div class="logo_small"><a href="/"><img src="' + logo.url(:medium) + '" border="0"></a></div>'
  end  
  
  def logo_small
    return nil unless has_logo?
    '<div class="logo_small"><a href="/"><img src="' + logo.url(:icon_140) + '" border="0"></a></div>'
  end
  
  def tags_name_plural
    tags_name.pluralize
  end

end
