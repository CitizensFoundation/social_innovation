# Copyright (C) 2009,2010 Róbert Viðar Bjarnason
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

module PortalHelper
  def default_portal_update(portal_html,portal_container, admin)
    page<<"jQuery('#main-portal-div').html('#{portal_html}');"
    page << "setup_columns();"
  end

  def setup_priorities_newest(limit, tag_name = nil)
    get_cached_priorities("Priority.published.filtered.newest.item_limit(#{limit})")
    {:priorities=>@priorities, :endorsements=>get_endorsements, :more=>newest_priorities_url}
  end

  def setup_priorities_top(limit, tag_name = nil)
    get_cached_priorities("Priority.published.filtered.top_rank.item_limit(#{limit})")
    {:priorities=>@priorities, :endorsements=>get_endorsements, :more=>top_priorities_url}
  end

  def setup_priorities_top_24hr(limit, tag_name = nil)
    get_cached_priorities("Priority.published.filtered.top_24hr.item_limit(#{limit})")
    {:priorities=>@priorities, :endorsements=>get_endorsements, :more=>top_24hr_priorities_url}
  end

  def setup_priorities_top_7days(limit, tag_name = nil)
    get_cached_priorities("Priority.published.filtered.top_7days.item_limit(#{limit})")
    {:priorities=>@priorities, :endorsements=>get_endorsements, :more=>top_7days_priorities_url}
  end

  def setup_priorities_top_30days(limit, tag_name = nil)
    get_cached_priorities("Priority.published.filtered.top_30days.item_limit(#{limit})")
    {:priorities=>@priorities, :endorsements=>get_endorsements, :more=>top_30days_priorities_url}
  end

  def setup_priorities_rising(limit, tag_name = nil)
    get_cached_priorities("Priority.published.filtered.rising.item_limit(#{limit})")
    {:priorities=>@priorities, :endorsements=>get_endorsements, :more=>rising_priorities_url}
  end

  def setup_priorities_tagged(limit, tag_name = nil)
    tag = Tag.find_or_create_by_name(tag_name)
    get_cached_priorities("Priority.filtered.tagged_with('#{tag.name}', :on => :issues).published.limit(#{limit})")
    {:priorities=>@priorities, :endorsements=>get_endorsements, :more=> "/issues/#{tag.to_url}"}
  end

  def setup_priorities_falling(limit, tag_name = nil)
    get_cached_priorities("Priority.published.filtered.falling.item_limit(#{limit})")
    {:priorities=>@priorities, :endorsements=>get_endorsements, :more=>falling_priorities_url}
  end

  def setup_priorities_controversial(limit, tag_name = nil)
    get_cached_priorities("Priority.published.filtered.controversial.item_limit(#{limit})")
    {:priorities=>@priorities, :endorsements=>get_endorsements, :more=>controversial_priorities_url}
  end

  def setup_priorities_finished(limit, tag_name = nil)
    get_cached_priorities("Priority.filtered.finished.not_deleted.by_random.item_limit(#{limit})")
    {:priorities=>@priorities, :endorsements=>get_endorsements, :more=>finished_priorities_url}
  end

  def setup_priorities_latest_processes(limit, tag_name = nil)
    get_cached_priorities("PriorityProcess.latest_updated_priorities(#{limit})")
    {:priorities=>@priorities, :endorsements=>get_endorsements, :more=>nil}
  end
  
  def setup_priorities_process_icesave(limit, tag_name = nil)
    #@priorities = [Priority.find(1), Priority.find(264), Priority.find(224), Priority.find(147),Priority.find(93)]
    {:priorities=>@priorities, :endorsements=>get_endorsements, :more=>nil}
  end

  def setup_priorities_random(limit, tag_name = nil)
    if User.adapter == 'postgresql'
      @priorities = Priority.published.filtered.paginate :order => "RANDOM()", :page => 1, :per_page => limit
    else
      @priorities = Priority.published.filtered.paginate :order => "rand()", :page => 1, :per_page => limit
    end
    {:more=>random_priorities_url, :priorities=>@priorities, :endorsements=>get_endorsements}
  end
  
  private
  
  def get_cached_priorities(code_function)
    key = code_function.gsub("(","").gsub(")","")+"sub_instance#{SubInstance.current_id}"
    @priorities = Rails.cache.read(key)
    if not @priorities
      eval("@priorities = #{code_function}")
      if @priorities and @priorities.respond_to?('all')
        Rails.cache.write(key, @priorities.all, :expires_in => 5.minutes)
      elsif @priorities
        Rails.cache.write(key, @priorities, :expires_in => 5.minutes)
      end
    end
  end

  def get_endorsements
    endorsements = nil
    #Rails.logger.debug("get endorsments: #{@priorities.inspect}")
    if logged_in? # pull all their endorsements on the priorities shown
      endorsements = current_user.endorsements.active.find(:all, :conditions => ["priority_id in (?)", @priorities.collect {|c| c.id}])
    end
    endorsements
  end
end
