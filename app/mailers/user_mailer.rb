class UserMailer < ActionMailer::Base
    
  helper :application

  # so DelayedJob will know how to make absolute urls
  def url_options
    { host: Instance.current.domain_name }.merge(super)
  end

  def welcome(user)
    @recipient = @user = user
    @instance = Instance.current
    recipients  = "#{user.real_name.titleize} <#{user.email}>"
    attachments.inline['logo.png'] = get_conditional_logo
    mail :to=>recipients,
         :reply_to => Instance.current.admin_email,
         :from => "#{tr(Instance.current.name,"Name from database")} <#{Instance.current.admin_email}>",
         :subject=>tr("Thank you for registering at {instance_name}","email", :instance_name => tr(Instance.current.name,"Name from database")) do |format|
           format.text { render :text=>convert_to_text(render_to_string("welcome", formats: [:html])) }
           format.html
         end
  end

  def lost_or_gained_capital(user, activity, point_difference)
    @instance = Instance.current
    @user = user
    @activity = activity
    @point_difference = point_difference
    @recipient = @user = user
    recipient = "#{user.real_name.titleize} <#{user.email}>"
    attachments.inline['logo.png'] = get_conditional_logo

    if point_difference > 0
      subject = tr('You just gained {points} social point(s) at {instance_name}', "email", points: point_difference.abs, :instance_name => tr(Instance.current.name,"Name from database"))
    else
      subject = tr('You just lost {points} social point(s) at {instance_name}', "email", points: point_difference.abs, :instance_name => tr(Instance.current.name,"Name from database"))
    end

    mail to:       recipient,
         reply_to: Instance.current.admin_email,
         from:     "#{tr(Instance.current.name,"Name from database")} <#{Instance.current.admin_email}>",
         subject:  subject do |format|
      format.text { render text: convert_to_text(render_to_string("lost_or_gained_capital", formats: [:html])) }
      format.html
    end
  end

  def idea_status_update(idea, status, status_date, status_subject, status_message, user, position)
    @idea = idea
    @instance = Instance.current
    @status = status
    @date = status_date
    @status_subject = status_subject
    @message = status_message
    @support_or_endorse_text = position == 1 ? tr("which you support", "email") : tr("which you oppose", "email")
    attachments.inline['logo.png'] = get_conditional_logo

    @recipient = @user = user
    recipient = "#{user.real_name.titleize} <#{user.email}>"
    mail to:       recipient,
         reply_to: Instance.current.admin_email,
         from:     "#{tr(Instance.current.name,"Name from database")} <#{Instance.current.admin_email}>",
         subject:  tr('The status of the idea "{idea}" has been changed', "email", :idea => idea.name) do |format|
      format.text { render text: convert_to_text(render_to_string("idea_status_update", formats: [:html])) }
      format.html
    end
  end

  def user_report(user, important, important_to_followers, near_top, frequency)
    freq_to_word = {
        2 => tr("Weekly", 'email'),
        1 => tr("Monthly", 'email')
    }
    freq = freq_to_word[frequency]
    subject = tr("{frequency} status report from {instance_name}", 'email', frequency: freq, instance_name: Instance.current.name)
    @instance = Instance.current
    @important = important
    @important_to_followers = important_to_followers
    @near_top = near_top
    @recipient = @user = user
    recipient = "#{user.real_name.titleize} <#{user.email}>"
    attachments.inline['logo.png'] = get_conditional_logo
    mail to:       recipient,
         reply_to: Instance.current.admin_email,
         from:     "#{tr(Instance.current.name,"Name from database")} <#{Instance.current.admin_email}>",
         subject:  subject do |format|
      format.text { render text: convert_to_text(render_to_string("user_report", formats: [:html])) }
      format.html
    end

  end

  def invitation(user,sender_name,to_name,to_email)
    @sender = @recipient = @user = user
    @instance = Instance.current
    @sender_name = sender_name
    @to_name = to_name
    @to_email = to_email
    @recipients = ""
    @recipients += to_name + ' ' if to_name
    @recipients += '<' + to_email + '>'
    attachments.inline['logo.png'] = get_conditional_logo
    mail :to => @recipients,
         :reply_to => Instance.current.admin_email,
         :from => "#{tr(Instance.current.name,"Name from database")} <#{Instance.current.admin_email}>",
         :subject => tr("Invitation from {sender_name} to join {instance_name}","email", :sender_name=>sender_name, :instance_name => tr(Instance.current.name,"Name from database")) do |format|
           format.text { render :text=>convert_to_text(render_to_string("invitation", formats: [:html])) }
           format.html
         end
  end  

  def new_password(user,new_password)
    @recipient = @user = user
    @new_password = new_password
    @instance = Instance.current
    recipients  = "#{user.real_name.titleize} <#{user.email}>"
    attachments.inline['logo.png'] = get_conditional_logo
    mail :to=>recipients,
         :reply_to => Instance.current.admin_email,
         :from => "#{tr(Instance.current.name,"Name from database")} <#{Instance.current.admin_email}>",
         :subject => tr("Your new temporary password","email") do |format|
           format.text { render :text=>convert_to_text(render_to_string("new_password"), formats: [:html]) }
           format.html
         end
  end
  
  def notification(n,sender,recipient,notifiable)
    @n = @notification = n
    @sender = sender
    @instance = Instance.current
    user = @user = @recipient = recipient
    @notifiable = notifiable
    Rails.logger.info("Notification class: #{@n} #{@n.class.to_s}  #{@n.inspect} notifiable: #{@notifiable}")
    recipients  = "#{user.real_name.titleize} <#{user.email}>"
    attachments.inline['logo.png'] = get_conditional_logo
    Rails.logger.info("Notification class: #{@n} #{@n.class.to_s}")
    mail :to => recipients,
         :reply_to => Instance.current.admin_email,
         :from => "#{tr(Instance.current.name,"Name from database")} <#{Instance.current.admin_email}>",
         :subject => @notification.name do |format|
      format.text { render :text=>convert_to_text(render_to_string("user_mailer/notifications/#{@n.class.to_s.underscore}", formats: [:html])) }      
      format.html { render "user_mailer/notifications/#{@n.class.to_s.underscore}" }
    end
  end
  
  def report(user,ideas,questions,documents,treaty_documents)
    @instance = Instance.current
    @recipients  = "#{user.login} <#{user.email}>"
    @from        = "#{tr(Instance.current.name,"Name from database")} <#{Instance.current.email}>"
    headers        "Reply-to" => Instance.current.email
    @sent_on     = Time.now
    @content_type = "text/html"
    @ideas = ideas
    @questions = questions
    @documents = documents
    @treaty_documents = treaty_documents
    @subject = tr("Report", "model/mailer")
  end
  
#   def new_change_vote(sender,recipient,vote)
#     setup_notification(recipient)
#     @subject = "Your " + Instance.current.name + " vote is needed: " + vote.change.idea.name
#     @body[:vote] = vote
#     @body[:change] = vote.change
#     @body[:recipient] = recipient
#     @body[:sender] = sender
#   end 
  
  protected
    def setup_notification(user)
      @recipients  = "#{user.login} <#{user.email}>"
      @from        = "#{tr(Instance.current.name,"Name from database")} <#{Instance.current.email}>"
      headers        "Reply-to" => Instance.current.email
      @sent_on     = Time.now
      @content_type = "text/html"     
      @body[:root_url] = 'http://' + Instance.current.base_url_w_sub_instance + '/'
    end

  private

    def get_conditional_logo
      if Instance.first.layout.include?("better_reykjavik")
        File.read(Rails.root.join("app/assets/images/logos/BR_email.png"))
      elsif Instance.first.layout.include?("better_iceland")
        File.read(Rails.root.join("app/assets/images/logos/betraIsland-merki.png"))
      elsif Instance.first.layout.include?("your_ideas")
        File.read(Rails.root.join("app/assets/images/logos/YourIdeas_large.png"))
      else
        File.read(Rails.root.join("app/assets/images/logos/default.gif"))
      end
    end

    # Returns the text in UTF-8 format with all HTML tags removed
    # From: https://github.com/jefflab/mail_style/tree/master/lib
    # TODO:
    #  - add support for DL, OL
    def convert_to_text(html, line_length = 65, from_charset = 'UTF-8')
      txt = html

      # decode HTML entities
      he = HTMLEntities.new
      begin
        txt = he.decode(txt)
      rescue
        txt = txt
      end

      # handle headings (H1-H6)
      txt.gsub!(/[ \t]*<h([0-9]+)[^>]*>(.*)<\/h[0-9]+>/i) do |s|
        hlevel = $1.to_i
        # cleanup text inside of headings
        htext = $2.gsub(/<\/?[^>]*>/i, '').strip
        hlength = (htext.length > line_length ?
                    line_length :
                    htext.length)

        case hlevel
          when 1   # H1, asterisks above and below
            ('*' * hlength) + "\n" + htext + "\n" + ('*' * hlength) + "\n"
          when 2   # H1, dashes above and below
            ('-' * hlength) + "\n" + htext + "\n" + ('-' * hlength) + "\n"
          else     # H3-H6, dashes below
            htext + "\n" + ('-' * htext.length) + "\n"
        end
      end

      # links
      txt.gsub!(/<a.*href=\"([^\"]*)\"[^>]*>(.*)<\/a>/i) do |s|
        $2.strip + ' ( ' + $1.strip + ' )'
      end

      # lists -- TODO: should handle ordered lists
      txt.gsub!(/[\s]*(<li[^>]*>)[\s]*/i, '* ')
      # list not followed by a newline
      txt.gsub!(/<\/li>[\s]*(?![\n])/i, "\n")

      # paragraphs and line breaks
      txt.gsub!(/<\/p>/i, "\n\n")
      txt.gsub!(/<br[\/ ]*>/i, "\n")

      # strip remaining tags
      txt.gsub!(/<\/?[^>]*>/, '')

      # wrap text
#      txt = r.format(('[' * line_length), txt)

      # remove linefeeds (\r\n and \r -> \n)
      txt.gsub!(/\r\n?/, "\n")

      # strip extra spaces
#      txt.gsub!(/\302\240+/, " ") # non-breaking spaces -> spaces
      txt.gsub!(/\n[ \t]+/, "\n") # space at start of lines
      txt.gsub!(/[ \t]+\n/, "\n") # space at end of lines

      # no more than two consecutive newlines
      txt.gsub!(/[\n]{3,}/, "\n\n")

      txt.strip
    end          
end
