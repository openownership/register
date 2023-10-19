# frozen_string_literal: true

InvisibleCaptcha.setup do |config|
  config.honeypots = Rails.cache.fetch('invisible_captcha_honeypots') do
    (1..20).map { InvisibleCaptcha.generate_random_honeypot }
  end
  config.timestamp_enabled = !Rails.env.test?
end
