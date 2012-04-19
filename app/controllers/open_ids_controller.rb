class OpenIdsController < ApplicationController
  skip_before_filter :verify_authenticity_token
  
  def new
    store_previous_location
    response.headers['WWW-Authenticate'] = Rack::OpenID.build_header(
        :identifier => "https://www.google.com/accounts/o8/id",
        :required => ["http://axschema.org/contact/email",
                      "http://axschema.org/namePerson/first",
                      "http://axschema.org/namePerson/last"],
        :return_to => open_id_url,
        :method => 'POST')
    head 401
  end

  def create
    if openid = request.env[Rack::OpenID::RESPONSE]
      case openid.status
      when :success
        ax = OpenID::AX::FetchResponse.from_success_response(openid)
        if logged_in? # they are already logged in, need to sync this account to twitter
          user = User.find(current_user.id)
          user.identifier_url = openid.display_identifier
          user.save(false)
          flash[:notice] = tr("Your Google account is now linked", "controller/open_ids")
          redirect_back_or_default('/')
        else
          user = User.where(:identifier_url => openid.display_identifier).first
          if user
            self.current_user = user
            flash[:notice] = tr("Welcome back, {user_name}.", "controller/twitter", :instance_name => Instance.current.name, :user_name => current_user.name)
            redirect_back_or_default('/')
          else
            user = User.new(:identifier_url => openid.display_identifier,
                            :email => ax.get_single('http://axschema.org/contact/email'),
                            :first_name => ax.get_single('http://axschema.org/namePerson/first'),
                            :last_name => ax.get_single('http://axschema.org/namePerson/last'),
                            :login => "#{ax.get_single('http://axschema.org/namePerson/first')} #{ax.get_single('http://axschema.org/namePerson/last')}".strip)

            if user.save(false)
              user.activate!
              user.reload # Need to reload the user otherwise the welcome message triggers Encoding::CompatibilityError: incompatible character encodings: UTF-8 and ASCII-8BIT
              self.current_user = user
              check_geoblocking
              if @geoblocked
                flash[:notice] = tr("This part of the website is not avilable for login in your country.", "controller/twitter")
                redirect_back_or_default('/')
              else
                flash[:notice] = tr("Welcome, {user_name}.", "controller/open_ids", :user_name => current_user.name)
                redirect_back_or_default('/')
              end
            else
              flash[:error] = tr("Sign in from Google failed.", "controller/open_ids")
              redirect_back_or_default('/')
            end
          end
        end
      when :failure
        flash[:error] = tr("Sign in from Google failed.", "controller/open_ids")
        redirect_back_or_default('/')
      end
    else
      flash[:error] = tr("Sign in from Google failed.", "controller/open_ids")
      redirect_back_or_default('/')
    end
  end
end