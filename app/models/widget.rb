class Widget < ActiveRecord::Base

  belongs_to :user
  belongs_to :tag

  def priorities_available
    a = Array.new
    a << [ "top", tr("Top priorities", "model/widget") ]
    a << [ "rising", tr("Rising priorities", "model/widget") ]
    a << [ "falling", tr("Falling priorities", "model/widget") ]
    a << [ "random", tr("Random priorities", "model/widget") ]
    a << [ "newest", tr("New priorities", "model/widget") ]
    a << [ "controversial", tr("Controversial priorities", "model/widget") ]
    a << [ "finished", tr("Finished priorities", "model/widget") ]
    if Instance.current.has_official?
      a << [ "official", tr("{official_user_name} priorities", "model/widget", :official_user_name => Instance.current.official_user_short_name) ]
      a << [ "not_official", tr("Priorities NOT on {official_user_name} agenda", "model/widget", :official_user_name => Instance.current.official_user_short_name) ]
      a << [ "official_opposed", tr("Priorities {official_user_name} opposes", "model/widget", :official_user_name => Instance.current.official_user_short_name) ]
    end
    a
  end

  def discussions_available
    a = Array.new
    if false and user
      a << [ "your_discussions", tr("Your discussions", "model/widget") ]
      a << [ "your_network_discussions", tr("Discussions in your network", "model/widget") ]
      a << [ "your_priorities_discussions", tr("Discussions on your priorities", "model/widget") ]
      a << [ "your_priorities_created_discussions", tr("Discussions on priorities you created", "model/widget") ]
    end
    a << [ "discussions", tr("Active discussions", "model/widget") ]
  end
  
  def points_available
    [
      [ "index", tr("Your points", "model/widget") ],
      [ "your_priorities", tr("Points on your priorities", "model/widget")  ],                         
      [ "newest", tr("Newest points", "model/widget")  ]
    ]
  end
  
  def charts_available
    [
      [ "charts_priority", tr("Chart Priority", "model/widget") ],
      [ "charts_user", tr("Your priorities", "model/widget") ]
    ]
  end

  def javascript_url
    if self.attribute_present?("tag_id")
      s = 'issues/' + tag.slug + '/' + self.action_name
    else
      s = self.controller_name + "/" + self.action_name
    end
    if self.user
      Instance.current.homepage_url + s + ".js?user_id=" + self.user.id.to_s + "&per_page=" + number.to_s
    else
      Instance.current.homepage_url + s + ".js?per_page=" + number.to_s
    end
  end
  
  def javascript_code
    "<script src='" + javascript_url + "' type='text/javascript'></script>"
  end
  
end
