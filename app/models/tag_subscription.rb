class TagSubscription < ActiveRecord::Base
  belongs_to :user
  belongs_to :tag
end
