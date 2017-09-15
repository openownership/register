Rollbar.configure do |config|
  config.access_token = ENV['ROLLBAR_ACCESS_TOKEN']
  config.enabled = false if Rails.env.test? || Rails.env.development?
  if config.enabled
    config.environment = (PullRequestNumber.call || ENV.fetch('ROLLBAR_ENV'))
  end
  config.exception_level_filters.merge!('ActionController::UnknownFormat' => 'warning')
end
