# frozen_string_literal: true

require_relative 'boot'

require 'rails'
require 'active_model/railtie'
require 'active_job/railtie'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'action_view/railtie'
require 'sprockets/railtie'

Bundler.require(*Rails.groups)

module OpenOwnershipRegister
  class Application < Rails::Application
    config.load_defaults 6.0

    if ENV['BASIC_AUTH'].present?
      config.middleware.insert_after(ActionDispatch::Static, Rack::Auth::Basic) do |u, p|
        ENV['BASIC_AUTH'].split(':') == [u, p]
      end
    end

    config.action_mailer.delivery_method :smtp
    config.action_mailer.smtp_settings = {
      port: ENV.fetch('SMTP_PORT', nil),
      address: ENV.fetch('SMTP_ADDRESS', nil),
      user_name: ENV.fetch('SMTP_TOKEN', nil),
      password: ENV.fetch('SMTP_TOKEN', nil),
      authentication: :plain
    }

    host_uri = if ENV.key?('HEROKU_APP_NAME')
                 URI("https://#{ENV['HEROKU_APP_NAME']}.herokuapp.com")
               else
                 URI(ENV.fetch('SITE_BASE_URL'))
               end

    config.action_mailer.default_url_options = { host: host_uri.hostname }
    config.action_mailer.default_url_options[:port] = host_uri.port if host_uri.port != host_uri.default_port
    config.action_mailer.asset_host = host_uri.to_s

    self.default_url_options = config.action_mailer.default_url_options

    markdown     = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    markdown_sfx = '_md'

    config.x.data_sources = config_for(:data_sources).transform_values do |v|
      v.to_h do |k2, v2|
        if k2.end_with?(markdown_sfx)
          [k2.to_s.chomp(markdown_sfx).to_sym, markdown.render(v2)]
        else
          [k2, v2]
        end
      end
    end
  end
end
