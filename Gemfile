# frozen_string_literal: true

source "https://rubygems.org"

gem "active_model_serializers", "~> 0.10.0"
gem "api-pagination"
gem "aws-sdk-sqs", "~> 1.3"
gem "bcrypt", "~> 3.1.7"
gem "bolognese", "~> 2.1.0"
gem "bootsnap", "~> 1.2", ">= 1.2.1"
gem "cancancan", "~> 2.0"
gem "countries", "~> 2.1", ">= 2.1.2"
gem "country_select", "~> 3.1"
gem "dalli", "~> 2.7.6"
gem "dotenv"
gem "equivalent-xml", "~> 0.6.0"
gem "facets", require: false
gem "faraday_middleware-aws-sigv4", "~> 0.3.0"
gem "git", "~> 1.5"
gem "iso8601", "~> 0.9.0"
gem "jwt"
gem "kaminari", "~> 1.0", ">= 1.0.1"
gem "lograge", "~> 0.11.2"
gem "logstash-event", "~> 1.2", ">= 1.2.02"
gem "logstash-logger", "~> 0.26.1"
gem "maremma", "~> 4.9.6"
gem "nokogiri", "~> 1.13.2"
gem "oj", ">= 2.8.3"
gem "oj_mimic_json", "~> 1.0", ">= 1.0.1"
gem "rack-cors", "~> 1.0", require: "rack/cors"
gem "rack-utf8_sanitizer", "~> 1.6"
gem "rails", "6.1.7.3"
gem "sentry-raven", "~> 2.9"
gem "shoryuken", "~> 4.0"
gem "simple_command"
gem "slack-notifier", "~> 2.3", ">= 2.3.2"
gem "sprockets", "~> 3.7", ">= 3.7.2"
gem 'next_rails'
gem "json-canonicalization", '0.3.1'

group :development, :test do
  gem "better_errors"
  gem "byebug", platforms: %i[mri mingw x64_mingw]
  gem "rspec-rails", "~> 6.1", ">= 6.1.1"
  gem "rubocop", "~> 1.3", ">= 1.3.1"
  gem "rubocop-performance", "~> 1.5", ">= 1.5.1"
  gem "rubocop-rails", "~> 2.8", ">= 2.8.1"
end

group :development do
  gem "listen", ">= 3.0.5", "< 3.2"
  gem "spring"
  gem "spring-watcher-listen", "~> 2.0.0"
end

group :test do
  gem "capybara"
  gem "codeclimate-test-reporter", "~> 1.0.0"
  gem "factory_bot_rails", "~> 6.4", ">= 6.4.3"
  gem "faker", "~> 3.2", ">= 3.2.3"
  gem "rubocop-rspec", "~> 2.0", require: false
  gem "shoulda-matchers", "~> 4.1", ">= 4.1.2"
  gem "simplecov", "~> 0.22.0"
  gem "vcr", "~> 6.1"
  gem "webmock", "~> 3.1"
end
