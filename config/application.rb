require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "action_controller/railtie"
require "rails/test_unit/railtie"
require "active_job/logging"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# load ENV variables from .env file if it exists
env_file = File.expand_path("../.env", __dir__)
if File.exist?(env_file)
  require "dotenv"
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
ENV["APPLICATION"] ||= "levriero"
ENV["MEMCACHE_SERVERS"] ||= "memcached:11211"
ENV["SITE_TITLE"] ||= "DataCite Event Data Agents"
ENV["LOG_LEVEL"] ||= "info"
ENV["CONCURRENCY"] ||= "25"
ENV["GITHUB_URL"] ||= "https://github.com/datacite/levriero"
ENV["ORCID_API_URL"] ||= "https://pub.orcid.org/v2.1"
ENV["API_URL"] ||= "https://api.stage.datacite.org"
ENV["VOLPINO_URL"] ||= "https://api.stage.datacite.org"
ENV["LAGOTTINO_URL"] ||= "https://api.stage.datacite.org"
ENV["SASHIMI_QUERY_URL"] ||= "https://api.stage.datacite.org"
ENV["EVENTDATA_URL"] ||= "https://bus-staging.eventdata.crossref.org"
ENV["CROSSREF_QUERY_URL"] ||= "https://api.eventdata.crossref.org"
ENV["TRUSTED_IP"] ||= "10.0.40.1"
ENV["SLACK_WEBHOOK_URL"] ||= ""
ENV["USER_AGENT"] ||= "Mozilla/5.0 (compatible; Maremma/#{Maremma::VERSION}; mailto:info@datacite.org)"

module Levriero
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.1
    config.autoload_paths << Rails.root.join("lib")
    config.autoload_paths << Rails.root.join("app", "models", "concerns")

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # secret_key_base is not used by Rails API, as there are no sessions
    config.secret_key_base = "blipblapblup"

    # configure logging
    config.active_job.logger = nil
    config.lograge.enabled = true
    config.lograge.formatter = Lograge::Formatters::Logstash.new
    config.lograge.logger = LogStashLogger.new(type: :stdout)
    config.logger = config.lograge.logger        ## LogStashLogger needs to be pass to rails logger, see roidrage/lograge#26
    config.log_level = ENV["LOG_LEVEL"].to_sym   ## Log level in a config level configuration

    config.lograge.ignore_actions = ["HeartbeatController#index",
                                     "IndexController#index"]
    config.lograge.ignore_custom = lambda do |event|
      event.payload.inspect.length > 100000
    end
    config.lograge.base_controller_class = "ActionController::API"

    config.lograge.custom_options = lambda do |event|
      exceptions = %w(controller action format id)
      {
        params: event.payload[:params].except(*exceptions),
        uid: event.payload[:uid],
      }
    end

    # raise error with unpermitted parameters
    config.action_controller.action_on_unpermitted_parameters = :raise

    # compress responses with deflate or gzip
    config.middleware.use Rack::Deflater

    # make sure all input is UTF-8
    config.middleware.insert 0, Rack::UTF8Sanitizer,
                             additional_content_types: ["application/vnd.api+json", "application/xml"]

    # set Active Job queueing backend
    config.active_job.queue_adapter = if ENV["AWS_REGION"]
                                        :shoryuken
                                      else
                                        :inline
                                      end
    config.active_job.queue_name_prefix = Rails.env

    config.generators do |g|
      g.fixture_replacement :factory_bot
    end
  end
end
