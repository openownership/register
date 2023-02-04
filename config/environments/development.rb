Rails.application.configure do
  # Enable 10.0.2.2 for development to enable using NAT port forwarding through a VM
  config.web_console.permissions = '10.0.2.2'

  config.cache_classes = false
  config.eager_load = false
  config.consider_all_requests_local = true

  if Rails.root.join('tmp/caching-dev.txt').exist?
    config.action_controller.perform_caching = true
    config.public_file_server.headers = {
      'Cache-Control' => "public, max-age=#{2.days.to_i}",
    }
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
    else
      config.cache_store = :memory_store
    end
  else
    config.action_controller.perform_caching = false
    config.cache_store = :null_store
  end

  config.action_mailer.perform_caching = false
  config.active_support.deprecation = :log
  config.assets.debug = true
  config.assets.quiet = true
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker
  config.i18n.raise_on_missing_translations = true
  config.action_mailer.preview_path = Rails.root.join('app/mailers/previews')
end
