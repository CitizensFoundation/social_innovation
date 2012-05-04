class Message < ActiveRecord::Base

  scope :active, :conditions => "messages.status <> 'removed'"
  scope :sent, :conditions => "messages.status in('sent','read')"
  scope :read, :conditions => "messages.status = 'read'"
  scope :unread, :conditions => "messages.status = 'sent'"
  scope :draft, :conditions => "messages.status = 'draft'"
  
  scope :by_recently_sent, :order => "messages.sent_at desc"
  scope :by_oldest_sent, :order => "messages.sent_at asc"  
  scope :by_unread, :order => "messages.status desc, messages.sent_at desc"

  belongs_to :sender, :class_name => "User", :foreign_key => "sender_id"
  belongs_to :recipient, :class_name => "User", :foreign_key => "recipient_id"
  
  has_many :notifications, :as => :notifiable, :dependent => :destroy  
  
  validates_presence_of :content

  include Workflow
  workflow_column :status
  workflow do
    state :draft do
      event :send, transitions_to: :sent
      event :read, transitions_to: :read
      event :remove, transitions_to: :removed
    end
    state :sent do
      event :read, transitions_to: :read
      event :remove, transitions_to: :removed
    end
    state :read do
      event :remove, transitions_to: :removed
    end
    state :removed do
      event :unremove, transitions_to: :read, meta: { validates_presence_of: [:read_at] }
      event :unremove, transitions_to: :sent, meta: { validates_presence_of: [:sent_at] }
      event :unremove, transitions_to: :draft
    end
  end

  def on_sent_entry(new_state, event)
    self.removed_at = nil  
    if not Following.find_by_user_id_and_other_user_id_and_value(self.recipient_id,self.sender_id,-1) and self.sent_at.blank?
      self.notifications << NotificationMessage.new(:sender => self.sender, :recipient => self.recipient)
    end
    self.sent_at = Time.now
    save(:validate => false)
  end
  
  def on_read_entry(new_state, event)
    self.removed_at = nil
    self.read_at = Time.now
    save(:validate => false)
    for n in self.notifications
      n.read!
      Rails.cache.delete("views/" + n[:type].downcase + "-" + n.id.to_s)
    end
  end
  
  def on_removed_entry(new_state, event)
    self.removed_at = Time.now
    save(:validate => false)
    for n in self.notifications
      n.remove!
    end    
  end
  
  cattr_reader :per_page
  @@per_page = 25
  
  def unread?
    self.status == 'sent'
  end
  
  def recipient_name
    recipient.name if recipient
  end
  
  def recipient_name=(n)
    self.recipient = User.find_by_login(n) unless n.blank?
  end  
  
  auto_html_for(:content) do
    html_escape
    youtube :width => 330, :height => 210
    vimeo :width => 330, :height => 180
    link :target => "_blank", :rel => "nofollow"
  end  
  
end
