require_relative 'boot'

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "sprockets/railtie"

Bundler.require(*Rails.groups)

module OpenOwnershipRegister
  class Application < Rails::Application
    if ENV["BASIC_AUTH"].present?
      config.middleware.insert_before(Rack::Sendfile, Rack::Auth::Basic) do |u, p|
        [u, p] == ENV["BASIC_AUTH"].split(':')
      end
    end
  end
end
