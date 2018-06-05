ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../config/environment', __dir__)
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'spec_helper'
require 'rspec/rails'
require 'support/devise'
require 'support/submission_helpers'
require 'support/admin_helpers'

require 'sidekiq/testing'
Sidekiq::Logging.logger = nil

Dir["./spec/shared_examples/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.before(:all) do
    Mongoid::Tasks::Database.remove_undefined_indexes
    Mongoid::Tasks::Database.create_indexes
  end
end
