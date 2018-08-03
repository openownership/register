Rails.application.config.blocked_ips = ENV.fetch('BLOCKED_IPS', '').split(',').map(&:strip)

X_FORWARDED_FOR_HEADER = 'HTTP_X_FORWARDED_FOR'.freeze

Rack::Attack.blocklist("blocked IPs") do |request|
  ips = request.get_header(X_FORWARDED_FOR_HEADER)
  if ips.present?
    ips.split(',').map(&:strip).map(&:presence).compact.any? do |ip|
      Rails.application.config.blocked_ips.include?(ip)
    end
  end
end
