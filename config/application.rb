require_relative 'boot'

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "action_controller/railtie"
require "rails/test_unit/railtie"
require 'syslog/logger'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# load ENV variables from .env file if it exists
env_file = File.expand_path("../../.env", __FILE__)
if File.exist?(env_file)
  require 'dotenv'
  Dotenv.load! env_file
end

# load ENV variables from container environment if json file exists
# see https://github.com/phusion/baseimage-docker#envvar_dumps
env_json_file = "/etc/container_environment.json"
if File.exist?(env_json_file)
  env_vars = JSON.parse(File.read(env_json_file))
  env_vars.each { |k, v| ENV[k] = v }
end

# default values for some ENV variables
ENV['APPLICATION'] ||= "elastic-api"
ENV['HOSTNAME'] ||= "levriero.local"
ENV['MEMCACHE_SERVERS'] ||= "memcached:11211"
ENV['SITE_TITLE'] ||= "DataCite REST API"
ENV['LOG_LEVEL'] ||= "info"
ENV['ES_HOST'] ||= "elasticsearch:9200"
ENV['ES_NAME'] ||= "elasticsearch"
ENV['CONCURRENCY'] ||= "25"
ENV['GITHUB_URL'] ||= "https://github.com/datacite/levriero"
ENV['API_URL'] ||= "https://api.test.datacite.org"
ENV['APP_URL'] ||= "https://app.test.datacite.org"
ENV['CDN_URL'] ||= "https://assets.datacite.org"
ENV['VOLPINO_URL'] ||= "https://profiles.test.datacite.org/api"
ENV['RE3DATA_URL'] ||= "https://www.re3data.org/api/beta"
ENV['TRUSTED_IP'] ||= "10.0.40.1"

module Levriero
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.1
    config.autoload_paths << Rails.root.join('lib')
    config.autoload_paths << Rails.root.join("app", "models", "concerns")

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # secret_key_base is not used by Rails API, as there are no sessions
    config.secret_key_base = 'blipblapblup'

    # configure logging
    logger = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger = ActiveSupport::TaggedLogging.new(logger)
    config.lograge.enabled = true
    config.log_level = ENV['LOG_LEVEL'].to_sym

    # add elasticsearch instrumentation to logs
    require 'elasticsearch/rails/lograge'

    config.cache_store = :dalli_store, nil, { namespace: ENV['APPLICATION'] }

    # raise error with unpermitted parameters
    config.action_controller.action_on_unpermitted_parameters = :raise

    # compress responses with deflate or gzip
    config.middleware.use Rack::Deflater

    # set Active Job queueing backend
    if ENV['AWS_REGION']
      config.active_job.queue_adapter = :shoryuken
    else
      config.active_job.queue_adapter = :inline
    end
    config.active_job.queue_name_prefix = Rails.env

    config.generators do |g|
      g.fixture_replacement :factory_bot
    end
  end
end
