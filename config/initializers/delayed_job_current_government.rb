Delayed::Worker.logger = Rails.logger

module Delayed
  class PerformableMethod

    self.class_eval do
      attr_accessor :custom_data
    end

    def initialize(object, method_name, custom_data, args)
      raise NoMethodError, "undefined method `#{method_name}' for #{object.inspect}" unless object.respond_to?(method_name, true)

      self.object       = object
      self.custom_data  = custom_data
      self.args         = args
      self.method_name  = method_name.to_sym
    end

    def perform
      Instance.current = Instance.first
      if custom_data
        SubInstance.current = SubInstance.find(custom_data)
      else
        SubInstance.current = nil
      end
      object.send(method_name, *args) if object
    end
    
  end
  
  class PerformableMailer < PerformableMethod
    def perform
      Instance.current = Instance.first
      if custom_data
        SubInstance.current = SubInstance.find(custom_data)
      else
        SubInstance.current = nil
      end
      object.send(method_name, *args).deliver
    end
  end

  module DelayMail
    def delay(options = {})
      custom_value = SubInstance.current ? SubInstance.current.id : nil
      DelayProxy.new(PerformableMailer, self, custom_value, options)
    end
  end
end

module Delayed
  class DelayProxy
    def initialize(payload_class, target, custom_data=nil, options={})
      @payload_class = payload_class
      @target = target
      @options = options
      @custom_data = custom_data
    end

    def method_missing(method, *args)
      Job.enqueue({:payload_object => @payload_class.new(@target, method.to_sym, @custom_data, args)}.merge(@options))
    end
  end

  module MessageSending
    def delay(options = {})           
      custom_value = SubInstance.current ? SubInstance.current.id : nil
      DelayProxy.new(PerformableMethod, self, custom_value, options)
    end
  end
end
