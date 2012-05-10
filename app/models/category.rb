class Category < ActiveRecord::Base
  has_many :ideas
  has_many :blog_posts
  has_attached_file :icon, :styles => { :icon_32 => "32x32#", :icon_25 => "25x25#", :icon_40  => "40x40#", :icon_50  => "50x50#", :icon_100 => "100x100#" }

  validates_attachment_size :icon, :less_than => 5.megabytes
  validates_attachment_content_type :icon, :content_type => ['image/png']

  def i18n_name
    tr(self.name, "model/category")
  end
  
  def to_url
    "/issues/#{self.name.parameterize_full[0..60]}"
  end
  
  def self.for_sub_instance
    if SubInstance.current and Category.where(:sub_instance_id=>SubInstance.current.id).count > 0
      Category.where(:sub_instance_id=>SubInstance.current.id).order("name")
    else
      Category.where(:sub_instance_id=>nil).order("name")
    end
  end
end
