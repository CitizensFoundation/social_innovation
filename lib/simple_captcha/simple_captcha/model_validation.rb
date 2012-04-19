# Copyright (c) 2008 [Sur http://expressica.com]

module SimpleCaptcha #:nodoc
  module ModelValidation #:nodoc

    def self.included(base)
      base.extend ClassMethods
    end

    # To implement model based simple captcha use this method in the model as...
    #
    #  class User < ActiveRecord::Base
    #    validates_captcha :message => "Are you a bot?"
    #  end
    # 
    # Configuration options:
    #
    #   * :add_to_base - Specifies if error should be added to base or captcha field. defaults to false.
    #   * :message - A custom error message (default is: "Secret Code did not match with the Image")
    #   * :on - Specifies when this validation is active (default is :save, other options :create, :update)
    #   * :if - Specifies a method, proc or string to call to determine if the validation should occur (e.g. :if => :allow_validation, or :if => Proc.new { |user| user.signup_step > 2 }). The method, proc or string should return or evaluate to a true or false value.
    #   * :unless - Specifies a method, proc or string to call to determine if the validation should not occur (e.g. :unless => :skip_validation, or :unless => Proc.new { |user| user.signup_step <= 2 }). The method, proc or string should return or evaluate to a true or false value.
    #
    module ClassMethods
      
      def validates_captcha(options = {})
        orig_options = options
        # AR by default looks into the following i18n scope :
        # :'activerecord.errors.messages.record_invalid'
        options = { :message => :captcha }
        options.update(orig_options)

        attr_accessor :captcha, :captcha_key 
        include SimpleCaptcha::ModelValidation::InstanceMethods

        validate =
          case (options[:on] || :save)
            when :save   then :validate
            when :create then :validate_on_create
            when :update then :validate_on_update
          end
        send(validate, options) do |record|
          if !record.captcha_validation?
            true
          elsif record.captcha_is_valid?
            true
          elsif options[:add_to_base]
            record.errors.add_to_base(options[:message])
            false
          else
            record.errors.add(:captcha, options[:message])
            false
          end
        end
      end

      def apply_simple_captcha(options = {}) # 4 backward compatibility
        outcome = validates_captcha(options)
        self.captcha_validation = false
        include SimpleCaptcha::ModelValidation::SaveWithCaptcha
        outcome
      end

      def captcha_validation?
        defined?(@_captcha_validation) ? @_captcha_validation : true
      end

      def captcha_validation=(flag)
        @_captcha_validation = flag
      end

    end

    module InstanceMethods

      def captcha_is_valid?
        SimpleCaptcha::CaptchaUtils.simple_captcha_matches?(captcha, captcha_key)
      end

      def captcha_validation?
        if defined?(@_captcha_validation) && ! @_captcha_validation.nil?
          @_captcha_validation
        else
          self.class.captcha_validation?
        end
      end

      def captcha_validation(flag = true)
        prev = @_captcha_validation
        @_captcha_validation = flag
        if block_given?
          outcome = yield
          @_captcha_validation = prev
        end
        outcome
      end

    end

    module SaveWithCaptcha

      if defined?(ActiveModel) && ActiveModel::VERSION::MAJOR >= 3

        def save_with_captcha(options = {})
          options[:validate] = true unless options.has_key?(:validate)
          captcha_validation(true) { save(options) }
        end

      else

        def save_with_captcha
          captcha_validation(true) { save }
        end

      end
    end


  end
end
