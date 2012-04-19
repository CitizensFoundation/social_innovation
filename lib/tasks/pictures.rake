namespace :pictures do  

  desc "clear out existing paperclip"
  task :clear => :environment do
    
    for g in Instance.all
      g.logo = nil
      g.buddy_icon = nil
      g.fav_icon = nil
      g.save(:validate => false)
    end

    for u in User.find(:all, :conditions => "picture_id is not null")
      u.buddy_icon = nil
      u.save(:validate => false)
    end

    for p in SubInstance.find(:all, :conditions => "picture_id is not null")
      p.logo = nil
      p.save(:validate => false)
    end
    
  end
  
  desc "import old pictures table into paperclip/s3"
  task :import => :environment do
   
   for g in Instance.all
     if g.picture and not g.attribute_present?("logo_file_name")
       file_name = Rails.root.to_s + "/tmp/" + g.picture.name
       file = File.open(file_name, 'w') {|f| f.write(g.picture.data) }
       g.logo = File.new(file_name)
       File.delete(file_name)
     end
     if g.buddy_icon_old and not g.attribute_present?("buddy_icon_file_name")
       file_name = Rails.root.to_s + "/tmp/" + g.buddy_icon_old.name
       file = File.open(file_name, 'w') {|f| f.write(g.buddy_icon_old.data) }
       g.buddy_icon = File.new(file_name)
       File.delete(file_name)
     end     
     if g.fav_icon_old and not g.attribute_present?("fav_icon_file_name")
       file_name = Rails.root.to_s + "/tmp/" + g.fav_icon_old.name
       file = File.open(file_name, 'w') {|f| f.write(g.fav_icon_old.data) }
       g.fav_icon = File.new(file_name)
       File.delete(file_name)
     end
     g.save(:validate => false)
   end

   for u in User.find(:all, :conditions => "picture_id is not null")
     if u.picture and not u.attribute_present?("buddy_icon_file_name")
       file_name = Rails.root.to_s + "/tmp/" + u.picture.name
       file = File.open(file_name, 'w') {|f| f.write(u.picture.data) }
       u.buddy_icon = File.new(file_name)
       File.delete(file_name)
       u.save(:validate => false)
     end
   end
   
   for p in SubInstance.find(:all, :conditions => "picture_id is not null")
     if p.picture and not p.attribute_present?("logo_file_name")
       file_name = Rails.root.to_s + "/tmp/" + p.picture.name
       file = File.open(file_name, 'w') {|f| f.write(p.picture.data) }
       p.logo = File.new(file_name)
       File.delete(file_name)
       p.save(:validate => false)
     end
   end   
   
  end
  
end