class Tagging < ActiveRecord::Base
  
  belongs_to :tag
  belongs_to :taggable, :polymorphic => true
  belongs_to :tagger, :polymorphic => true
  
  validates_presence_of :context
  
  belongs_to :idea, :class_name => "Idea", :foreign_key => "taggable_id"
  belongs_to :feed, :class_name => "Feed", :foreign_key => "taggable_id"
      
  after_create :increment_tag
  before_destroy :decrement_tag
  
  def increment_tag
    return unless tag
    if taggable.class == Idea
      tag.increment!(:ideas_count)
      tag.update_counts # recalculate the discussions/points
      tag.save(:validate => false)
    elsif taggable.class == Feed
      tag.increment!(:feeds_count)      
    end
  end
  
  def decrement_tag
    return unless tag
    if taggable.class == Idea
      tag.decrement!(:ideas_count)
      tag.update_counts # recalculate the discussions/points
      tag.save(:validate => false)
    elsif taggable.class == Feed
      tag.decrement!(:feeds_count)        
    end    
  end
  
end