Rails.application.configure do
  config.cache_classes = true
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  config.read_encrypted_secrets = false # We don't use encrypted secrets
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?
  config.assets.resolve_with = %i[manifest]
  config.assets.compile = false
  config.log_level = :info
  config.log_tags = [:request_id]
  config.action_mailer.perform_caching = false
  config.i18n.fallbacks = [I18n.default_locale]
  config.active_support.deprecation = :notify
  config.log_formatter = ::Logger::Formatter.new
  config.force_ssl = true

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger = ActiveSupport::Logger.new($stdout)
    logger.formatter = config.log_formatter
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  end

  if ENV["MEMCACHE_SERVERS"].present?
    memcached_servers = ENV.fetch('MEMCACHE_SERVERS').split(',')
    memcached_config = {
      username: ENV.fetch('MEMCACHE_USERNAME'),
      password: ENV.fetch('MEMCACHE_PASSWORD'),
      failover: true,
      socket_timeout: 1.5,
      socket_failure_delay: 0.2,
      down_retry_delay: 60,
    }
    config.cache_store = :mem_cache_store, *memcached_servers, memcached_config
  end
end
