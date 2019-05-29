Devise.setup do |config|
  config.mailer_sender = if ENV.key?('HEROKU_APP_NAME')
    format '"OpenOwnership Register (%{app_name})" <register+%{app_name}@openownership.org>', app_name: ENV['HEROKU_APP_NAME']
  else
    '"OpenOwnership Register" <register@openownership.org>'
  end

  config.parent_mailer = 'ApplicationMailer'
  require 'devise/orm/mongoid'

  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]
  config.skip_session_storage = [:http_auth]
  config.stretches = Rails.env.test? ? 1 : 11
  config.reconfirmable = true
  config.password_length = 6..128
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/
  config.reset_password_within = 6.hours
  config.sign_out_via = :delete
end
