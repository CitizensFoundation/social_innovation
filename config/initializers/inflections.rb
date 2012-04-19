# coding: utf-8

# Be sure to restart your server when you modify this file.

# Add new inflection rules using the following format
# (all these examples are active by default):
# ActiveSupport::Inflector.inflections do |inflect|
#   inflect.plural /^(ox)$/i, '\1en'
#   inflect.singular /^(ox)en/i, '\1'
#   inflect.irregular 'person', 'people'
#   inflect.uncountable %w( fish sheep )
# end
class String
  def parameterize_full
    str=self.to_s
    accents = {
      ['á','à','â','ä','ã'] => 'a',
      ['Ã','Ä','Â','À','Á'] => 'A',
      ['é','è','ê','ë'] => 'e',
      ['Ë','É','È','Ê'] => 'E',
      ['í','ì','î','ï'] => 'i',
      ['Í','Î','Ì','Ï'] => 'I',
      ['ó','ò','ô','ö','õ'] => 'o',
      ['Õ','Ö','Ô','Ò','Ó'] => 'O',
      ['ú','ù','û','ü'] => 'u',
      ['Ú','Û','Ù','Ü'] => 'U',
      ['Ý'] => 'Y',
      ['ý'] => 'y',
      ['Ð'] => 'D',
      ['ð'] => 'd',
      ['Þ'] => 'Th',
      ['þ'] => 'th',
      ['Æ'] => 'Ae',
      ['æ'] => 'ae',
      ['Æ'] => 'Ae',
      ['æ'] => 'ae',
      ['ç'] => 'c', ['Ç'] => 'C',
      ['ñ'] => 'n', ['Ñ'] => 'N'
    }
    accents.each do |ac,rep|
      ac.each do |s|
        str = str.gsub(s, rep)
      end
    end
    str = str.gsub(/[^a-zA-Z0-9 ]/,"")
    str = str.gsub(/[ ]+/," ")
    str = str.gsub(/ /,"-")
    str = str.downcase
  end
  
  def downcase_is
    self.to_s.gsub("Ð","ð").gsub("Þ","þ").gsub("Æ","æ").gsub("Á","á").gsub("É","é").gsub("Í","í").gsub("Ý","ý").gsub("Ú","ú").gsub("Ó","ó").gsub("Ö","ö").downcase
  end
  
  def titleize_is
    out_words=[]
    self.downcase_is.split.each do |word|
      if ["ð","þ","æ","á","é","í","ý","ú","ó","ö"].include?(word[0..1])
        word[0..1]=word[0..1].gsub("ð","Ð").gsub("þ","Þ").gsub("æ","Æ").gsub("á","Á").gsub("é","É").gsub("í","Í").gsub("ý","Ý").gsub("ú","Ú").gsub("ó","Ó").gsub("ö","Ö")
      else
        word[0]=word[0..0].upcase
      end
      out_words<<word
    end
    out_words.join(" ")
  end
end
