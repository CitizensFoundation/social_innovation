require File.dirname(__FILE__) + '/simple_captcha/captcha_utils'
require File.dirname(__FILE__) + '/simple_captcha/image_helpers'
require File.dirname(__FILE__) + '/simple_captcha/view_helpers'
#require 'simple_captcha/controller_validation'
#require 'simple_captcha/model_validation'

#ActiveRecord::Base.extend SimpleCaptcha::ModelHelpers::ClassMethods
ActionView::Base.send :include, SimpleCaptcha::ViewHelpers

module SimpleCaptcha

  @@image_options = {
      :image_color => 'white',
      :image_size => '110x30',
      :text_color => 'black',
      :text_font => 'arial',
      :text_size => 22
  }
  def self.image_options
    @@image_options
  end

  def self.image_options=(options)
    @@image_options.merge! options
  end

  @@captcha_length = nil
  def self.captcha_length
    @@captcha_length ||= 6
  end

  def self.captcha_length=(length)
    if length
      raise "invalid captcha length < 0 : #{length}" if length <= 0
      raise "invalid captcha length > 20 : #{length}" if length > 20
    end
    @@captcha_length = length
  end

  @@backend = nil
  def self.backend
    self.backend = :RMagick unless @@backend
    @@backend
  end

  def self.backend=(backend)
    if backend.nil?
      return @@backend = nil
    end
    if backend.is_a?(Symbol) || backend.is_a?(String)
      backend = backend.to_s.camelize
      backend_const = const_get(backend + 'Backend') rescue nil
      backend_const = const_get(backend) rescue nil unless backend_const
      raise "unsupported backend: #{backend}" unless backend_const
    else
      backend_const = backend
    end
    unless backend_const.respond_to?(:generate_simple_captcha_image)
      raise "invalid backend: #{backend_const} - does not respond to :generate_simple_captcha_image"
    end
    @@backend = backend_const
  end

end
