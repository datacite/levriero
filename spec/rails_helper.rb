ENV['RAILS_ENV'] = 'test'
ENV['ES_HOST'] ||= "elasticsearch:9200"
ENV["TEST_CLUSTER_NODES"] = "1"

# set up Code Climate
require 'simplecov'
SimpleCov.start

require File.expand_path('../../config/environment', __FILE__)

Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

# require "rspec/rails"
# Load any of our adapters and extensions early in the process
require 'rspec/rails/adapters'
require 'rspec/rails/extensions'

# Load the rspec-rails parts
require 'rspec/rails/view_rendering'
require 'rspec/rails/matchers'
require 'rspec/rails/fixture_support'
require 'rspec/rails/file_fixture_support'
require 'rspec/rails/fixture_file_upload_support'
require 'rspec/rails/example'

require 'rspec/rails/configuration'

require "shoulda-matchers"
require "webmock/rspec"
require "rack/test"
require "colorize"


# Checks for pending migration and applies them before tests are run.
# ActiveRecord::Migration.maintain_test_schema!
WebMock.allow_net_connect!

# WebMock.disable_net_connect!(
#   allow: ['codeclimate.com:443', ENV['PRIVATE_IP'], ENV['ES_HOST'],  ENV['API_URL'],  ENV['APP_URL']],
#   allow_localhost: true
# )

# configure shoulda matchers to use rspec as the test framework and full matcher libraries for rails
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

RSpec.configure do |config|
  # add `FactoryBot` methods
  config.include FactoryBot::Syntax::Methods
  # don't use transactions, use database_clear gem via support file
  # config.use_transactional_fixtures = false

  # add custom json method
  config.include RequestSpecHelper, type: :request
end

