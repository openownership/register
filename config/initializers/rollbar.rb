Rollbar.configure do |config|
  config.access_token = ENV['ROLLBAR_ACCESS_TOKEN']
  config.enabled = false if Rails.env.test? || Rails.env.development?
  if config.enabled
    config.environment = if ENV['HEROKU_APP_NAME'].present?
      ENV['HEROKU_APP_NAME'][/(?<=-)pr-\d+$/]
    else
      ENV.fetch('ROLLBAR_ENV')
    end
  end
end
