# frozen_string_literal: true

# rubocop:disable Layout/ExtraSpacing

source 'https://rubygems.org'
ruby File.read('.ruby-version').strip

gem 'addressable',                      '~> 2.8'
gem 'aws-sdk-s3',                       '~> 1.114'
gem 'bootsnap',                         '~> 1.13',          require: false
gem 'bootstrap',                        '=4.0.0.alpha5'
gem 'coderay',                          '~> 1.1'
gem 'countries'
gem 'dalli',                            '~> 3.2'
gem 'draper',                           '~> 4.0'
gem 'elasticsearch',                    '=7.10.1'
gem 'faraday',                          '~> 1.9.3'
gem 'faraday_middleware',               '~> 1.2'
gem 'font-awesome-sass',                '~> 4.7.0'
gem 'geokit',                           '~> 1.13'
gem 'haml-rails',                       '~> 2.1'
gem 'hashie',                           '~> 3.4', '>= 3.4.4'
gem 'iso8601',                          '~> 0.13'
gem 'kaminari',                         '~> 1.2'
gem 'net-http-persistent',              '~> 4.0'
gem 'puma',                             '~> 5.6'
gem 'rails',                            '~> 6.1'
gem 'redcarpet',                        '~> 3.5'
gem 'rexml',                            '~> 3.2'
gem 'rubyzip',                          '~> 2.3',           require: false
gem 'sass-rails',                       '~> 6.0'
gem 'sprockets',                        '~> 4.1'
gem 'sprockets-rails',                  '~> 3.4'
gem 'twitter_cldr',                     '~> 6.11'
gem 'webpacker',                        '~> 5.4'
gem 'xxhash',                           '~> 0.5'

gem 'register_common',       git: 'https://github.com/openownership/register-common.git'
gem 'register_sources_bods', git: 'https://github.com/openownership/register-sources-bods.git'
gem 'register_sources_dk',   git: 'https://github.com/openownership/register-sources-dk.git',
                             branch: '180-paginate-raw-records'
gem 'register_sources_oc',   git: 'https://github.com/openownership/register-sources-oc.git'
gem 'register_sources_psc',  git: 'https://github.com/openownership/register-sources-psc.git',
                             branch: '180-paginate-raw-records'
gem 'register_sources_sk',   git: 'https://github.com/openownership/register-sources-sk.git',
                             branch: '180-paginate-raw-records'

group :development, :test do
  gem 'byebug',                         '~> 11.1'
end

group :development do
  gem 'haml_lint',                                          require: false
  gem 'listen',                         '~> 3.7.0'
  gem 'rubocop',                                            require: false
  gem 'rubocop-rails',                                      require: false
  gem 'spring',                         '~> 2.1'
  gem 'web-console',                    '~> 4.2'
end

group :test do
  gem 'capybara',                       '~> 3.37'
  gem 'selenium-webdriver',             '~> 4.3'
  gem 'webdrivers',                     '~> 5.0'
end

# rubocop:enable Layout/ExtraSpacing
