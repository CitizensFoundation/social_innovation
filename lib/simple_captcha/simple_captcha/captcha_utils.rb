# Copyright (c) 2008 [Sur http://expressica.com]

require 'digest/sha1'

module SimpleCaptcha #:nodoc
  module CaptchaUtils

    def self.simple_captcha_value(key)
      SimpleCaptchaData.get_data(key).value rescue nil
    end

    def self.simple_captcha_matches?(captcha, key)
      captcha && captcha.delete(" ").upcase == simple_captcha_value(key)
    end

    def self.simple_captcha_passed!(key)
      SimpleCaptchaData.remove_data(key)
    end

    def simple_captcha_value
      SimpleCaptcha::CaptchaUtils.simple_captcha_value(simple_captcha_key)
    end

    def simple_captcha_matches?(captcha)
      SimpleCaptcha::CaptchaUtils.simple_captcha_matches?(captcha, simple_captcha_key)
    end

    def simple_captcha_passed!
      SimpleCaptcha::CaptchaUtils.simple_captcha_passed!(simple_captcha_key).tap do
        session[:simple_captcha] = nil
      end
    end

    def simple_captcha_key
      session[:simple_captcha] ||= generate_simple_captcha_key
    end

    def generate_simple_captcha_key
      session_id = session[:id] || 
        request.respond_to?(:session_options) ?
          request.session_options[:id] : session.session_id
      Digest::SHA1.hexdigest(Time.now.to_s + session_id.to_s)
    end

  end
end
