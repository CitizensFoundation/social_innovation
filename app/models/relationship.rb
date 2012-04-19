class Relationship < ActiveRecord::Base

  scope :who_endorsed, :conditions => "relationships.type in ('RelationshipEndorserEndorsed','RelationshipOpposerEndorsed','RelationshipUndecidedEndorsed')"
  scope :endorsers_endorsed, :conditions => "relationships.type = 'RelationshipEndorserEndorsed'"
  scope :opposers_endorsed, :conditions => "relationships.type = 'RelationshipOpposerEndorsed'"
  scope :undecideds_endorsed, :conditions => "relationships.type = 'RelationshipUndecidedEndorsed'"    
  scope :by_highest_percentage, :order => "relationships.percentage desc"

  belongs_to :priority
  belongs_to :other_priority, :class_name => "Priority"
  
  after_create :add_counts
  before_destroy :remove_counts
  
  def add_counts
    Priority.update_all("relationships_count = relationships_count + 1", "id = #{self.priority_id}")
  end
  
  def remove_counts
    Priority.update_all("relationships_count = relationships_count - 1", "id = #{self.priority_id}")
  end
  
end

class RelationshipEndorserEndorsed < Relationship
  
end

class RelationshipOpposerEndorsed < Relationship
  
end

class RelationshipUndecidedEndorsed < Relationship
  
end
