Rails.application.config.blocked_ips = ENV.fetch('BLOCKED_IPS', '').split(',').map(&:strip)

X_FORWARDED_FOR_HEADER = 'X-Forwarded-For'.freeze

Rack::Attack.blocklist("blocked IPs") do |request|
  ip = request.get_header(X_FORWARDED_FOR_HEADER)
  Rails.application.config.blocked_ips.include?(ip) if ip.present?
end
