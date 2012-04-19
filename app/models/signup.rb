class Signup < ActiveRecord::Base
  
  belongs_to :user
  belongs_to :sub_instance, :counter_cache => "users_count"
  
end
