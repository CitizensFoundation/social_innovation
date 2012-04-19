module ActiveRecord 
  class Base 
    def self.tr(a,b,c={})
      Tr8n::Language.translate(a,b,c)
    end

    def tr(a,b,c={})
      Tr8n::Language.translate(a,b,c)
    end
  end 
end

module ActionMailer
  class Base 
    def self.tr(a,b,c={})
      Tr8n::Language.translate(a,b,c)
    end

    def tr(a,b,c={})
      Tr8n::Language.translate(a,b,c)
    end
  end 
end

locales = []
Dir.glob(Rails.root.to_s + '/config/locales/*.{rb,yml}') do |filename|

  if md = filename.match(/([\w\-]+)\.(rb|yml)$/)
    locales << md[1]
  end
  locales  
end

ENABLED_I18_LOCALES = locales