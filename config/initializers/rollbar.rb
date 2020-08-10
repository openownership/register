Rollbar.configure do |config|
  config.access_token = ENV['ROLLBAR_ACCESS_TOKEN']
  config.anonymize_user_ip = true
  config.scrub_fields << [:user_email]
  # Only collect ids, no personal data
  config.person_username_method = ''
  config.person_email_method = ''

  config.enabled = false if Rails.env.test? || Rails.env.development?
  if config.enabled
    config.environment = (PullRequestNumber.call || ENV.fetch('ROLLBAR_ENV'))
  end
  config.exception_level_filters.merge!('ActionController::UnknownFormat' => 'warning')
end
