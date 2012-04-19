
require 'RMagick'

module SimpleCaptcha

  module RMagickBackend

    def self.generate_simple_captcha_image(options)
      width, height = options[:image_size].split('x')
      
      image = Magick::Image.new(width.to_i, height.to_i) do
        self.background_color = options[:image_color]
        self.format = 'JPG'
      end

      image = set_simple_captcha_image_style(image, options)
      image.implode(0.2).to_blob
    end

    private

    def self.set_simple_captcha_image_style(image, options)
      amplitude, frequency = options[:distortion]
      case options[:image_style]
      when 'embosed_silver'
        append_simple_captcha_code(image, options)
        image = image.wave(amplitude, frequency).shade(true, 20, 60)
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
        image = image.wave(amplitude, frequency).charcoal
      when 'almost_invisible'
        options[:text_color] = 'red'
        append_simple_captcha_code(image, options)
        image = image.wave(amplitude, frequency).solarize
      else
        append_simple_captcha_code(image, options)
        image = image.wave(amplitude, frequency)
      end
      return image
    end

    def self.append_simple_captcha_code(image, options)
      text = Magick::Draw.new
      text.annotate(image, 0, 0, 0, 5, options[:captcha_text]) do
        self.font_family = options[:text_font]
        self.pointsize = options[:text_size]
        self.fill = options[:text_color]
        self.gravity = Magick::CenterGravity
      end
    end

  end

end
