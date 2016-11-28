Rollbar.configure do |config|
  config.access_token = ENV['ROLLBAR_ACCESS_TOKEN']
  config.enabled = false if Rails.env.test? || Rails.env.development?
  config.environment = if ENV['HEROKU_APP_NAME'].present?
    ENV['HEROKU_APP_NAME'].sub("#{ENV['HEROKU_PARENT_APP_NAME']}-", "")
  else
    Rails.env
  end
end
