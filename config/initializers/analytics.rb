# frozen_string_literal: true

Rails.application.config.enable_analytics = (ENV.fetch('ENABLE_ANALYTICS', '') == 'true')

Rails.application.config.ga_tracking_id = ENV.fetch 'GA_TRACKING_ID' if Rails.application.config.enable_analytics
