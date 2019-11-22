Rails.application.config.blocked_ips = ENV.fetch('BLOCKED_IPS', '').split(',').map(&:strip)
Rails.application.config.blocked_uas = ENV.fetch('BLOCKED_USER_AGENTS', '').split(',').map(&:strip)

X_FORWARDED_FOR_HEADER = 'HTTP_X_FORWARDED_FOR'.freeze

Rack::Attack.blocklist("blocked IPs") do |request|
  ips = request.get_header(X_FORWARDED_FOR_HEADER)
  if ips.present?
    ips.split(',').map(&:strip).map(&:presence).compact.any? do |ip|
      Rails.application.config.blocked_ips.include?(ip)
    end
  end
end

Rack::Attack.blocklist("blocked user agents") do |request|
  ua = request.user_agent
  if ua.present?
    Rails.application.config.blocked_uas.any? do |blocked_ua|
      ua.match(Regexp.new(blocked_ua, Regexp::IGNORECASE))
    end
  end
end

# Hacky throttle with exponential backoff, so that people get banned for
# increasingly long periods if they continue to exceed reasonable usage
# See: https://github.com/kickstarter/rack-attack/wiki/Advanced-Configuration#exponential-backoff
# Allows 20 requests in 8 seconds
#        40 requests in 64 seconds
#        ...
#        100 requests in 0.38 days (~250 requests/day)
(1..5).each do |level|
  Rack::Attack.throttle("ip/#{level}", limit: (20 * level), period: (8**level).seconds) do |req|
    req.ip unless asset_path?(req.path)
  end
end

def asset_path?(path)
  path.start_with?('/assets') \
    || path.start_with?('/packs') \
    || path.start_with?('/favicon')
end
