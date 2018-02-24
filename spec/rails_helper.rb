ENV['RAILS_ENV'] = 'test'
ENV["TEST_CLUSTER_NODES"] = "1"

# set up Code Climate
require 'simplecov'
SimpleCov.start

require File.expand_path('../../config/environment', __FILE__)

Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

require "rspec/rails"
require "shoulda-matchers"
require "webmock/rspec"
require "rack/test"
require "colorize"

WebMock.allow_net_connect!

WebMock.disable_net_connect!(
  allow: ['codeclimate.com:443', 'eleasticsearch:9200'],
  allow_localhost: true
)

# configure shoulda matchers to use rspec as the test framework and full matcher libraries for rails
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  # add custom json method
  config.include RequestSpecHelper, type: :request
end

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.ignore_localhost = true
  config.ignore_hosts "codeclimate.com", "elasticsearch"
  config.configure_rspec_metadata!
end
