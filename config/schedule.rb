# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever

set :output, "/home/yrpri/sites/social-innovation/master/shared/log/cron_log.log"

every 5.minutes do
  rake "schedule:fix_top_endorsements"
end

every 15.minutes do
  rake "ts:index"
end

every :reboot do
  rake "ts:index"
  rake "ts:start"
  command "cd /home/yrpri/sites/social-innovation/master/current; RAILS_ENV=production ruby script/delayed_job start RAILS_ENV=production"
end

every 50.minutes do
  rake "schedule:idea_ranker"
end

every 55.minutes do
  rake "schedule:user_ranker"
end

every 6.hours do
  rake "schedule:fix_counts"
end
