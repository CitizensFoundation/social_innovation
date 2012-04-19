# Copyright (c) 2008 [Sur http://expressica.com]

module SimpleCaptcha #:nodoc
  module ImageHelpers #:nodoc

    def generate_simple_captcha_image(options = {})
      options = SimpleCaptcha.image_options.merge(options)
      key = options.delete(:simple_captcha_key)
      captcha_text = SimpleCaptcha::CaptchaUtils.simple_captcha_value(key)
      options[:captcha_text] = captcha_text
      options[:distortion] = distortion(options[:distortion])
      options[:image_style] = image_style(options[:image_style])
      SimpleCaptcha.backend.generate_simple_captcha_image(options)
    end

    IMAGE_STYLES = [
      'embosed_silver',
      'simply_red',
      'simply_green',
      'simply_blue',
      'distorted_black',
      'all_black',
      'charcoal_grey',
      'almost_invisible'
    ]

    private

      def image_style(key)
        return IMAGE_STYLES[rand(IMAGE_STYLES.length)] if key == 'random'
        IMAGE_STYLES.include?(key) ? key : nil # 'simply_blue'
      end

      DISTORTIONS = ['low', 'medium', 'high']

      def distortion(key)
        key = key == 'random' ?
          DISTORTIONS[rand(DISTORTIONS.length)] :
          DISTORTIONS.include?(key) ? key : 'low'
        case key
          when 'low' then return [0 + rand(2), 80 + rand(20)]
          when 'medium' then return [2 + rand(2), 50 + rand(20)]
          when 'high' then return [4 + rand(2), 30 + rand(20)]
        end
      end

  end

end
