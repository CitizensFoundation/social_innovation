# Copyright (c) 2008 [Sur http://expressica.com]

module SimpleCaptcha #:nodoc
  module ControllerValidation #:nodoc

    include SimpleCaptcha::CaptchaUtils

    # This method is to validate the simple captcha in controller.
    # It means when the captcha is controller based i.e. :object has not been passed to the method show_simple_captcha.
    #
    # *Example*
    #
    # If you want to save an object say @user only if the captcha is validated then do like this in action...
    #
    #  if simple_captcha_valid?
    #   @user.save
    #  else
    #   flash[:notice] = "captcha did not match"
    #   redirect_to :action => "myaction"
    #  end
    def simple_captcha_valid?
      if captcha = params[:captcha]
        result = simple_captcha_matches?(captcha)
        simple_captcha_passed! if result
        result
      else
        false
      end
    end

  end
end
