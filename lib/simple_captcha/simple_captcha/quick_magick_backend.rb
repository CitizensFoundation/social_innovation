
require 'quick_magick'

module SimpleCaptcha

  module QuickMagickBackend

    def self.generate_simple_captcha_image(options)
      width, height = options[:image_size].split('x')
      
      image = QuickMagick::Image::solid(width, height, options[:image_color])
      image.format = 'JPG'

      image = set_simple_captcha_image_style(image, options)
      image.implode(0.2).to_blob
    end

    private

    def self.set_simple_captcha_image_style(image, options)
      amplitude, frequency = options[:distortion]
      case options[:image_style]
      when 'embosed_silver'
        append_simple_captcha_code(image, options)
        image = image.wave(amplitude, frequency).shade('20x60')
      when 'simply_red'
        options[:text_color] = 'darkred'
        append_simple_captcha_code(image, options)
        image = image.wave(amplitude, frequency)
      when 'simply_green'
        options[:text_color] = 'darkgreen'
        append_simple_captcha_code(image, options)
        image = image.wave(amplitude, frequency)
      when 'simply_blue'
        options[:text_color] = 'darkblue'
        append_simple_captcha_code(image, options)
        image = image.wave(amplitude, frequency)
      when 'distorted_black'
        append_simple_captcha_code(image, options)
        image = image.wave(amplitude, frequency).edge(10)
      when 'all_black'
        append_simple_captcha_code(image, options)
        image = image.wave(amplitude, frequency).edge(2)
      when 'charcoal_grey'
        append_simple_captcha_code(image, options)
        image = image.wave(amplitude, frequency).charcoal(0)
      when 'almost_invisible'
        options[:text_color] = 'red'
        append_simple_captcha_code(image, options)
        image = image.wave(amplitude, frequency).solarize(50)
      else
        append_simple_captcha_code(image, options)
        image = image.wave(amplitude, frequency)
      end
      return image
    end

    def self.append_simple_captcha_code(image, options)
      image.family = options[:text_font]
      image.pointsize = options[:text_size]
      image.fill = options[:text_color]
      image.gravity = 'center'
      image.draw_text 0, 5, options[:captcha_text]
    end

  end

end
