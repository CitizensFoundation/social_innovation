require File.expand_path('../boot', __FILE__)

require 'rails/all'

if defined?(Bundler)
  # If you precompile assets before deploying to production, use this line
  Bundler.require(*Rails.groups(:assets => %w(development test)))
  # If you want your assets lazily compiled in production, use this line
  # Bundler.require(:default, :assets, Rails.env)
end

module SocialInnovation
  class Application < Rails::Application

    require 'core_extensions'

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    # config.autoload_paths += %W(#{config.root}/extras)

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # Use SQL instead of Active Record's schema dumper when creating the database.
    # This is necessary if your schema can't be completely dumped by the schema dumper,
    # like if you have constraints or database-specific column types
    # config.active_record.schema_format = :sql

    # Enforce whitelist mode for mass assignment.
    # This will create an empty whitelist of attributes available for mass-assignment for all models
    # in your app. As such, your models will need to explicitly whitelist or blacklist accessible
    # parameters by using an attr_accessible or attr_protected declaration.
    config.active_record.whitelist_attributes = false

    # Enable the asset pipeline
    config.assets.enabled = true

    config.middleware.use 'Rack::OpenID'

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'
    config.filter_parameters = [:password, :password_confirmation]

    config.assets.initialize_on_precompile = true

    NB_CONFIG = { 'api_exclude_fields' => [:ip_address, :user_agent, :referrer, :google_token, :google_crawled_at, :activation_code, :salt, :email, :first_name, :last_name, :crypted_password, :is_tagger, :sub_instance_id, :ip_address, :user_agent, :remember_token, :remember_token_expires_at, :referrer, :zip, :birth_date, :city, :state, :is_comments_subscribed, :is_finished_subscribed, :is_followers_subscribed, :is_mergeable, :is_capital_subscribed, :is_messages_subscribed, :report_frequency, :is_point_changes_subscribed, :is_votes_subscribed, :is_subscribed, :contacts_count, :contacts_invited_count, :contacts_members_count, :contacts_not_invited_count, :code, :rss_code, :address] }
  end

  if defined?(PhusionPassenger)
    PhusionPassenger.on_event(:starting_worker_process) do |forked|
      # Only works with DalliStore
      Rails.cache.reset if forked
    end
  end

  require 'open-uri'
  require 'validates_uri_existence_of'

  require 'timeout'
  require 'authenticated_system'

  require 'load_windows_contacts'
  require 'load_yahoo_contacts'

  require 'diff'
end
