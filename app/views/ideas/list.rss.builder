xml.instruct! :xml, :version => "1.0"
xml.rss :version => "2.0" do
  xml.channel do
    xml.title @page_title
    xml.description tr(current_instance.name,"Name from database")
    xml.link url_for
    for idea in @ideas
      xml.item do
        xml.title '#' + idea.position.to_s + ' ' + idea.name
        xml.description render :partial => "ideas/show", :locals => {:idea => idea}
        xml.pubDate idea.created_at.to_s(:rfc822)
        xml.link idea_url(idea)
      end
    end
  end
end