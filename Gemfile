# frozen_string_literal: true

source "https://rubygems.org"

gem "active_model_serializers", "~> 0.10.16"
gem "addressable", "2.9"
gem "api-pagination", "~> 7.1"
gem "aws-sdk-sqs", "~> 1.112"
gem "bolognese", "~> 2.6"
gem "bootsnap", "~> 1.23"
gem "cancancan", "~> 3.6", ">= 3.6.1"
gem "dalli", "~> 5.0", ">= 5.0.2"
gem "dotenv", "~> 3.2"
gem "facets", require: false
gem "iso8601", "~> 0.13.0"
gem "jwt", "~> 3.1", ">= 3.1.2"
gem "kaminari", "~> 1.2", ">= 1.2.2"
gem "lograge", "~> 0.14.0"
gem "logstash-logger", "~> 1.0"
gem "maremma", "~> 6.0"
gem "nokogiri", "~> 1.19", ">= 1.19.2"
gem "oai", "~> 1.3"
gem "oj", "~> 3.16", ">= 3.16.17"
gem "oj_mimic_json", "~> 1.0", ">= 1.0.1"
gem "rack-cors", "~> 3.0", require: "rack/cors"
gem "rack-utf8_sanitizer", "~> 1.11", ">= 1.11.1"
gem "rails", "~> 8.1", ">= 8.1.3"
gem "sentry-raven", "~> 3.1", ">= 3.1.2"
gem "shoryuken", "~> 7.0", ">= 7.0.1"
gem "slack-notifier", "~> 2.4"
gem "sprockets", "~> 4.2", ">= 4.2.2"
gem "stringio", "3.2"
gem "next_rails", "~> 1.5"
gem 'msgpack', "~> 1.8"

group :development, :test do
  gem "byebug", "~> 13.0", platforms: %i[mri mingw x64_mingw]
  gem "rspec-rails", "~> 8.0", ">= 8.0.4"
  gem "rubocop", "~> 1.86", ">= 1.86.1"
  gem "rubocop-performance", "~> 1.26", ">= 1.26.1"
  gem "rubocop-rails", "~> 2.34", ">= 2.34.3"
end

group :development do
  gem "brakeman", "~> 8.0", ">= 8.0.4"
  gem "bundler-audit", "~> 0.9.3"
  gem "listen", "~> 3.10"
  gem "spring", "~> 4.4", ">= 4.4.2"
  gem "spring-watcher-listen", "~> 2.1"
end

group :test do
  gem "factory_bot_rails", "~> 6.5", ">= 6.5.1"
  gem "faker", "~> 3.6", ">= 3.6.1"
  gem "rubocop-rspec", "~> 3.9"
  gem "shoulda-matchers", "~> 7.0", ">= 7.0.1"
  gem "simplecov", "~> 0.22"
  gem "vcr", "~> 6.4"
  gem "webmock", "~> 3.26.2"
end
