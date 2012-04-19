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

class PortalController < ApplicationController
  before_filter :login_required, :only => [:new, :create, :destroy, :add_portlet, :save_positions, :delete_portlet]
  before_filter :admin_required, :only => [:edit, :update]

  caches_action :index, :if => proc {|c| c.do_action_cache? },
                        :cache_path => proc {|c| c.action_cache_path},
                        :expires_in => 5.minutes

  def index
    setup_portal
    
    respond_to do |format|
      format.html # index.html.erb
    end
  end

  def load_column_item
    @portlet = Portlet.find(params[:portlet_id])
    dyn_type = params[:dyn_type].to_i
    if dyn_type == 0
      @locals_data_function = "setup_priorities_top_24hr"
    elsif dyn_type == 1
      @locals_data_function = "setup_priorities_top_7days"
    elsif dyn_type == 2
      @locals_data_function = "setup_priorities_top_30days"
    elsif dyn_type == 3
      @locals_data_function = "setup_priorities_top"
    end
    render :partial=>"column_item", :locals=>{:portlet=>@portlet, :locals_data_function=>@locals_data_function}
  end

  def add_portlet
    setup_portal
    portlet=Portlet.new
    portlet.portlet_template_id = get_id_from_menu_url(params[:data])
    portlet.portlet_container_id = @portlet_container.id
    portlet.save
    
    portlet_pos = PortletPosition.new
    portlet_pos.css_column = 1
    portlet_pos.css_position = 0
    portlet_pos.portlet_id = portlet.id
    portlet_pos.save

    portal=escape_javascript(render_to_string :partial=>"portal")
    respond_to do |format|
      format.js do
        render :update do |page|
          page.default_portal_update(portal,@portlet_container,current_user.is_admin?)
        end
      end
    end
  end

  def delete_portlet
    setup_portal

    portlet = Portlet.find(params[:portlet_id].to_i)
    if portlet
      if portlet.portlet_container.default_admin and not current_user.is_admin?
        warn("Regular user trying to delete admin default portlet #{portlet.id}")
      else
        portlet.destroy
      end
    end

    portal=escape_javascript(render_to_string :partial=>"portal")
    respond_to do |format|
      format.js do
        render :update do |page|
          page.default_portal_update(portal,@portlet_container,current_user.is_admin?)
        end
      end
    end
  end
  
  def save_positions
    if current_user and current_user.is_admin?
      PortletPosition.transaction do
        params.each do |key,value|
          next unless key.index("portlet_id")
          portlet_id = key.split("-")[1].to_i
          next unless Portlet.exists?(portlet_id)
          portlet = Portlet.find(portlet_id, :include=>:portlet_container)
          dp = PortletPosition.find_by_portlet_id(portlet_id)
          dp.css_column = value.split("|")[0].to_i
          dp.css_position = value.split("|")[1].to_i
          if portlet.portlet_container.user_id == current_user.id or (current_user and current_user.is_admin?)
            dp.save
          else
            Rails.logger.error("Wrong user trying to save the wrong thing")
          end
        end
      end
    end
    render :nothing=>true
  end  

  private

  def default_container
    portlet_container = PortletContainer.filtered.find_by_default_admin(true)
    if portlet_container==nil and current_sub_instance and Instance.current.layout == "better_reykjavik"
      portlet_container = PortletContainer.find(:first, :conditions=>"sub_instance_id IS NOT NULL")
    else
      portlet_container = PortletContainer.first unless portlet_container
    end
    unless portlet_container
      if current_user
        portlet_container = PortletContainer.new
        portlet_container.default_admin = true
        portlet_container.user_id = current_user.id
        portlet_container.save
      end
    end
    portlet_container
  end

  def user_container
    portlet_container = PortletContainer.filtered.find_by_user_id(current_user.id)
    unless portlet_container
      if current_user
        portlet_container = PortletContainer.new
        portlet_container.user_id = current_user.id
        portlet_container.save
        portlet_container.clone_from_default(default_container)
      end
    end
    portlet_container
  end

  def setup_portal
    @portlet_container = default_container
    last = params[:last].blank? ? Time.now + 1.second : Time.parse(params[:last])
    @activities = Activity.active.top.feed(last).filtered.for_all_users.with_20
#    if not current_user or current_user.is_admin? or not logged_in?
#      @portlet_container = default_container
#   else
#      @portlet_container = user_container
#    end
  end

  def get_id_from_menu_url(data)
    pos=data.rindex("-")
    data[pos+1..data.length+1].to_i
  end
end
