Rails.application.config.assets.version = '1.0'

Rails.application.config.assets.precompile << proc do |_filename, path|
  path =~ %r{/vendor/assets/images/[A-Z]+\.svg$}
end

Rails.application.config.assets.precompile += %w(admin.css)
