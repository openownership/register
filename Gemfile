source 'https://rubygems.org'
ruby File.read(".ruby-version").strip

gem 'addressable', '~> 2.8'
gem 'rails', '~> 6.1'
gem 'puma', '~> 5.6'
gem 'sprockets-rails', '~> 3.4'
gem 'sprockets', '~> 4.1'
gem 'sass-rails', '~> 6.0'
gem 'haml-rails', '~> 2.1'
gem 'bootstrap', '=4.0.0.alpha5'
gem 'font-awesome-sass', '~> 4.7.0'

gem 'webpacker', '~> 5.4'

gem 'kaminari', '~> 1.2'
gem 'elasticsearch', '=7.10.1'
gem 'net-http-persistent', '~> 4.0'
gem 'parallel', '~> 1.22'
gem 'rollbar', '~> 3.3'
gem 'countries'
gem 'iso8601', '~> 0.13'
gem 'roadie-rails', '~> 2.3'
gem 'aws-sdk-s3', '~> 1.114'
gem 'rubyzip', '~> 2.3', require: false
gem 'twitter_cldr', '~> 6.11'
gem 'draper', '~> 4.0'
gem 'memoist', '~> 0.16'
gem 'rack-attack', '~> 6.6'
gem 'faraday', '~> 1.9.3'
gem 'faraday_middleware', '~> 1.2'
gem 'dalli', '~> 3.2'
gem 'bootsnap', '~> 1.13', require: false
gem 'redcarpet', '~> 3.5'
gem 'xxhash', '~> 0.5'
gem 'oj', '~> 3.13'
gem 'coderay', '~> 1.1'
gem 'geokit', '~> 1.13'
gem 'invisible_captcha', '~> 2.0'
gem 'rexml', '~> 3.2'
gem 'net-smtp', '~> 0.3', require: false
gem 'net-imap', '~> 0.3', require: false
gem 'net-pop', '~> 0.1', require: false
gem 'hashie', '~> 3.4', '>= 3.4.4'

gem 'register_common', git: 'https://github.com/openownership/register-common.git'
gem 'register_sources_oc', git: 'https://github.com/openownership/register-sources-oc.git'
gem 'register_sources_psc', git: 'https://github.com/openownership/register-sources-psc.git'
gem 'register_sources_bods', git: 'https://github.com/openownership/register-sources-bods.git'
gem 'register_sources_sk', path: '../register-sources-sk' # git: 'https://github.com/openownership/register-sources-sk.git', branch: 'raw-records'
gem 'register_sources_dk', git: 'https://github.com/openownership/register-sources-dk.git', branch: 'raw-records'

group :development, :test do
  gem 'byebug', '~> 11.1'
  gem 'rspec-rails', '~> 5.1'
  gem 'dotenv-rails', '~> 2.7'
  gem 'webmock', '~> 3.14'
  gem 'launchy', '~> 2.5'
  gem 'pry-byebug', '~> 3.9'
  gem 'factory_bot_rails', '~> 6.2'
end

group :development do
  gem 'web-console', '~> 4.2'
  gem 'listen', '~> 3.7.0'
  gem 'spring', '~> 2.1'
  gem 'spring-watcher-listen', '~> 2.0.1'
  gem 'rubocop', '~> 1.22.3', require: false
  gem 'rubocop-rails', '~> 2.15', require: false
  gem 'haml_lint', '~> 0.37.1', require: false
  gem 'spring-commands-rspec', '~> 1.0'
end

group :test do
  gem 'capybara', '~> 3.37'
  gem 'rails-controller-testing', '~> 1.0'
  gem "selenium-webdriver", '~> 4.3'
  gem "webdrivers", '~> 5.0'
  gem 'capybara-email', '~> 3.0'
end
