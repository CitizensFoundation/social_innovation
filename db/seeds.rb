# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#   
#   cities = City.create([{ :name => 'Chicago' }, { :name => 'Copenhagen' }])
#   Major.create(:name => 'Daley', :city => cities.first)

# Create Categories

# Create Portlet Templates

i = Instance.new
i.name = "Your Instance"
i.description = "Your Instance"
i.domain_name = "yourdomain.com"
i.layout = "application"
i.admin_name = "Your Admin Name"
i.admin_email = "admin@yourdomain.com"
i.email = "admin@yourdomain.com"
i.save(:validation=>false)

c = ColorScheme.new
c.save

si = SubInstance.new
si.short_name = "default"
si.name = "Your Default Sub Instance"
si.save(:validation=>false)

require 'activity_classes'

Instance.current = i

require 'activity'

u = User.new
u.login="Administrator"
u.password="admin"
u.first_name="Administrator"
u.last_name="Admin"
u.is_admin = true
u.password_confirmation="admin"
u.email="admin@admin.is"
u.save(:validation=>false)

Category.create(:name=>"New Products", :description => "")
Category.create(:name=>"Improved Services", :description => "")
Category.create(:name=>"Customer Satisfaction", :description => "")
Category.create(:name=>"Management", :description => "")
Category.create(:name=>"Future Vision", :description => "")
Category.create(:name=>"Marketing", :description => "")
Category.create(:name=>"Environment", :description => "")
Category.create(:name=>"Social Innovation", :description => "")
Category.create(:name=>"Economy", :description => "")
Category.create(:name=>"Staff Satisfaction", :description => "")
Category.create(:name=>"Security", :description => "")
Category.create(:name=>"Information Technology", :description => "")
Category.create(:name=>"Software Application", :description => "")
Category.create(:name=>"Social Responsability", :description => "")
Category.create(:name=>"Employee Wellbeing", :description => "")
