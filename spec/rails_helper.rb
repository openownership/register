ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../config/environment', __dir__)
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'spec_helper'
require 'rspec/rails'
require 'capybara/rails'
require 'capybara/rspec'
require 'capybara/email/rspec'
require 'support/capybara'
require 'support/devise'
require 'support/oc_api_helpers'
require 'support/submission_helpers'
require 'support/admin_helpers'
require 'support/bods_schema_matcher'
require 'support/user_helpers'
require 'support/entity_helpers'
require 'support/psc_stats_helpers'

require 'sidekiq/testing'
Sidekiq::Logging.logger = nil

Dir["./spec/shared_examples/**/*.rb"].each { |f| require f }
Dir["./spec/shared_contexts/**/*.rb"].each { |f| require f }

JSON::Validator.schema_reader = JSON::Schema::Reader.new(accept_uri: false, accept_file: true)

RSpec.configure do |config|
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.before(:all) do
    Mongoid::Tasks::Database.remove_undefined_indexes
    Mongoid::Tasks::Database.create_indexes
  end
end
