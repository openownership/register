# frozen_string_literal: true

Rollbar.configure do |config|
  config.access_token = ENV.fetch('ROLLBAR_ACCESS_TOKEN', nil)
  config.anonymize_user_ip = true
  config.scrub_fields << [:user_email]
  # Only collect ids, no personal data
  config.person_username_method = ''
  config.person_email_method = ''

  config.enabled = false if Rails.env.test? || Rails.env.development?
  config.environment = (PullRequestNumber.call || ENV.fetch('ROLLBAR_ENV')) if config.enabled
  config.exception_level_filters.merge!('ActionController::UnknownFormat' => 'warning')
end
