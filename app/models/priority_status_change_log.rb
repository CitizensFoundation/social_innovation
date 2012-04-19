class PriorityStatusChangeLog < ActiveRecord::Base
  belongs_to :priority
  has_many :activities, :dependent => :destroy
end
