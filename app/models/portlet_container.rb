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

class PortletContainer < ActiveRecord::Base
  has_many :portlets do
    def in_column_order(css_column,portlet_container_id)
      Portlet.find :all, :include=>[:portlet_position,:portlet_container], :conditions=>["portlet_positions.css_column = ? AND portlets.portlet_container_id = ?",css_column,portlet_container_id], 
                                    :order=>"portlet_positions.css_position"
    end
  end
  
  acts_as_set_sub_instance :table_name=>"portlet_containers"
  
  def clone_from_default(default)
    default.portlets.each do |portlet|
      new_portlet = portlet.clone
      new_portlet.portlet_container_id = self.id
      new_portlet.save
      portlet_position = PortletPosition.find_by_portlet_id(portlet.id)
      new_portlet_position = portlet_position.clone
      new_portlet_position.portlet_id = new_portlet.id
      new_portlet_position.save
    end    
  end
end
