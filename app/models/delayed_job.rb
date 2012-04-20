class DelayedJob < ActiveRecord::Base

  scope :by_idea, :order => "locked_by asc, idea desc, run_at asc"
  
end
