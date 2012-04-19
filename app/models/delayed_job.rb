class DelayedJob < ActiveRecord::Base

  scope :by_priority, :order => "locked_by asc, priority desc, run_at asc"
  
end
