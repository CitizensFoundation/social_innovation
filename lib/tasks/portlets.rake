namespace :portlets do
  desc "initialize"
  task(:initialize => :environment) do
    pc=PortletTemplateCategory.new
    pc.name="Ideas"
    pc.weight = 1
    pc.save
    
    pc2=PortletTemplateCategory.new
    pc2.name="Categories"
    pc2.weight = 2
    pc2.save
    
    pc3=PortletTemplateCategory.new
    pc3.name="Network"
    pc3.weight = 3
    pc3.save
    
    pc4=PortletTemplateCategory.new
    pc4.name="News"
    pc4.weight = 4
    pc4.save
    
    pc5=PortletTemplateCategory.new
    pc5.name="Processes"
    pc5.weight = 4
    pc5.save

    p=PortletTemplate.new
    p.name="Latest Ideas"
    p.portlet_template_category_id=pc.id
    p.locals_data_function="setup_ideas_newest"
    p.partial_name = "idea_newest"
    p.item_limit = 3
    p.weight = 1
    p.save
    
    p=PortletTemplate.new
    p.name="Top Ideas"
    p.portlet_template_category_id=pc.id
    p.locals_data_function="setup_ideas_top"
    p.partial_name = "idea_list"
    p.item_limit = 3
    p.weight = 2
    p.save
    
    p=PortletTemplate.new
    p.name="Rising Ideas"
    p.portlet_template_category_id=pc.id
    p.locals_data_function="setup_ideas_rising"
    p.partial_name = "idea_list"
    p.item_limit = 3
    p.weight = 3
    p.save
    
    p=PortletTemplate.new
    p.name="Falling Ideas"
    p.portlet_template_category_id=pc.id
    p.locals_data_function="setup_ideas_falling"
    p.partial_name = "idea_list"
    p.item_limit = 3
    p.weight = 4
    p.save
    
    p=PortletTemplate.new
    p.name="Controversial Ideas"
    p.portlet_template_category_id=pc.id
    p.locals_data_function="setup_ideas_controversial"
    p.partial_name = "idea_list"
    p.item_limit = 3
    p.weight = 5
    p.save
    
    p=PortletTemplate.new
    p.name="Finished Ideas"
    p.portlet_template_category_id=pc.id
    p.locals_data_function="setup_ideas_finished"
    p.partial_name = "idea_list"
    p.item_limit = 3
    p.weight = 6
    p.save
    
    p=PortletTemplate.new
    p.name="Random Ideas"
    p.portlet_template_category_id=pc.id
    p.locals_data_function="setup_ideas_random"
    p.partial_name = "idea_list"
    p.item_limit = 5
    p.weight = 7
    p.caching_disabled = true
    p.save
    
    p=PortletTemplate.new
    p.name="Category Cloud"
    p.portlet_template_category_id=pc2.id
    p.locals_data_function=nil
    p.partial_name = "issues_cloud"
    p.item_limit = nil
    p.weight = 1
    p.save
    
    p=PortletTemplate.new
    p.name="Category List"
    p.portlet_template_category_id=pc2.id
    p.locals_data_function=nil
    p.partial_name = "issues_list"
    p.item_limit = 3
    p.weight = 2
    p.save
    
    p=PortletTemplate.new
    p.name="Most Active Users"
    p.portlet_template_category_id=pc3.id
    p.locals_data_function=nil
    p.partial_name = "network_list"
    p.item_limit = 5
    p.weight = 1
    p.save
    
    p=PortletTemplate.new
    p.name="Newest Users"
    p.portlet_template_category_id=pc3.id
    p.locals_data_function=nil
    p.partial_name = "network_newest"
    p.item_limit = 5
    p.weight = 2
    p.save
    
    p=PortletTemplate.new
    p.name="Ambassadors"
    p.portlet_template_category_id=pc3.id
    p.locals_data_function=nil
    p.partial_name = "network_ambassadors"
    p.item_limit = 5
    p.weight = 3
    p.save
    
    p=PortletTemplate.new
    p.name="Discussions"
    p.portlet_template_category_id=pc4.id
    p.locals_data_function=nil
    p.partial_name = "news_discussions"
    p.item_limit = 3
    p.weight = 1
    p.save
    
    p=PortletTemplate.new
    p.name="Points"
    p.portlet_template_category_id=pc4.id
    p.locals_data_function=nil
    p.partial_name = "news_points"
    p.item_limit = 7
    p.weight = 2
    p.save
    
    p=PortletTemplate.new
    p.name="Activities"
    p.portlet_template_category_id=pc4.id
    p.locals_data_function=nil
    p.partial_name = "news_activities"
    p.item_limit = 7
    p.weight = 3
    p.save
    
    p=PortletTemplate.new
    p.name="News political capital"
    p.portlet_template_category_id=pc4.id
    p.locals_data_function=nil
    p.partial_name = "news_capital"
    p.item_limit = 7
    p.weight = 4
    p.save
    
    p=PortletTemplate.new
    p.name="Changes"
    p.portlet_template_category_id=pc4.id
    p.locals_data_function=nil
    p.partial_name = "news_changes"
    p.item_limit = 7
    p.weight = 5
    p.save    

    p=PortletTemplate.new
    p.name="Latest Video Discussions"
    p.portlet_template_category_id=pc5.id
    p.locals_data_function=nil
    p.partial_name = "process_latest_video_discussions"
    p.item_limit = 20
    p.weight = 1
    p.save    

    p=PortletTemplate.new
    p.name="Most Popular Videos"
    p.portlet_template_category_id=pc5.id
    p.locals_data_function=nil
    p.partial_name = "process_most_popular_videos"
    p.item_limit = 10
    p.weight = 2
    p.save    

    p=PortletTemplate.new
    p.name="Latest Processes"
    p.portlet_template_category_id=pc5.id
    p.locals_data_function = "setup_ideas_latest_processes"
    p.partial_name = "idea_list"
    p.item_limit = 3
    p.weight = 3
    p.save    

    p=PortletTemplate.new
    p.name="Latest Process Documents"
    p.portlet_template_category_id=pc5.id
    p.locals_data_function=nil
    p.partial_name = "process_latest_documents"
    p.item_limit = 5
    p.weight = 4
    p.save

    p=PortletTemplate.new
    p.name="Icesave"
    p.portlet_template_category_id=pc5.id
    p.locals_data_function="setup_ideas_process_icesave"
    p.partial_name = "idea_list"
    p.item_limit = 3
    p.weight = 5
    p.save    
  end

  desc "initialize island.is"
  task(:initialize_island_is => :environment) do
    sub_instance = SubInstance.find_by_short_name("island")
    unless PortletTemplateCategory.find_by_name("island.is")
      pc=PortletTemplateCategory.new
      pc.name="island.is"
      pc.weight = 1
      pc.sub_instance_id = sub_instance.id
      pc.save
  
      p=PortletTemplate.new
      p.name="island.is"
      p.portlet_template_category_id=pc.id
      p.partial_name = "island_is_landshlutar"
      p.weight = 1
      p.save  
    end
  end
end
