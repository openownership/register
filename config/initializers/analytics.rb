Rails.application.config.enable_analytics = (ENV.fetch('ENABLE_ANALYTICS', '') == 'true')

if Rails.application.config.enable_analytics
  Rails.application.config.ga_tracking_id = ENV.fetch 'GA_TRACKING_ID'
end
