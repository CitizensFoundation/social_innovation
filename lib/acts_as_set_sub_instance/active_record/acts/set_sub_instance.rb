module ActiveRecord
  module Acts
    module SetSubInstance
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      module ClassMethods
        def acts_as_set_sub_instance(options = {})
          belongs_to :sub_instance
          before_create :set_sub_instance
      
          scope :filtered, lambda {{ :conditions=>"#{options[:table_name]}.sub_instance_id #{SubInstance.current ? "= #{SubInstance.current.id}" : "LIKE '%' OR #{options[:table_name]}.sub_instance_id IS NULL"}" }}
          class_eval <<-EOV
            include SetSubInstance::InstanceMethods
          EOV
        end
      end
      
      module InstanceMethods
        def set_sub_instance
    # DISABLED HACK
    #      if self.class.class_name=="Activity" and self.priority and self.priority.sub_instance
    #        self.sub_instance_id = self.priority.sub_instance.id
    #      else
            self.sub_instance_id = SubInstance.current.id if SubInstance.current
    #      end
        end
      end
    end
  end
end