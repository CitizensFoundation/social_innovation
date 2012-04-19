Airbrake.configure do |config|
  config.api_key = Rails.application.config.database_configuration[Rails.env]["airbrake_api_key"]
end
