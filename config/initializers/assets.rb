Rails.application.config.assets.version = '1.0'

Rails.application.config.assets.paths << Rails.root.join('node_modules').to_s

svg_imgs = Dir[Rails.root.join('vendor/assets/images/*.svg').to_s].map { |filepath| File.basename(filepath) }
Rails.application.config.assets.precompile += svg_imgs

Rails.application.config.assets.precompile += ['admin.css']
