ENV["RAILS_ENV"] = "test"
ENV["AWS_REGION"] = "eu-west-1"

# set up Code Climate
require "simplecov"
SimpleCov.start

require File.expand_path("../config/environment", __dir__)

Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

require "rspec/rails"
require "shoulda-matchers"
require "webmock/rspec"
require "rack/test"
require "colorize"

WebMock.allow_net_connect!

WebMock.disable_net_connect!(
  allow: ["codeclimate.com:443", "eleasticsearch:9201"],
  allow_localhost: true,
)

# configure shoulda matchers to use rspec as the test framework and full matcher libraries for rails
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

def fixture_path
  File.expand_path("fixtures", __dir__) + "/"
end

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  # add custom json method
  config.include RequestSpecHelper, type: :request
end

VCR.configure do |c|
  vcr_mode = /rec/i.match?(ENV["VCR_MODE"]) ? :all : :once

  sqs_host = "sqs.#{ENV['AWS_REGION']}.amazonaws.com"

  c.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  c.hook_into :webmock
  c.ignore_localhost = true
  c.ignore_hosts "codeclimate.com", "elasticsearch", sqs_host
  c.filter_sensitive_data("<VOLPINO_TOKEN>") { ENV["VOLPINO_TOKEN"] }
  c.filter_sensitive_data("<SLACK_WEBHOOK_URL>") { ENV["SLACK_WEBHOOK_URL"] }
  c.configure_rspec_metadata!
  c.default_cassette_options = { match_requests_on: %i[method uri] }
end

def capture_stdout
  original_stdout = $stdout
  $stdout = fake = StringIO.new
  begin
    yield
  ensure
    $stdout = original_stdout
  end
  fake.string
end
