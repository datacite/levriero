Raven.configure do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.release = "levriero:#{Levriero::Application::VERSION}"
  config.sanitize_fields = Rails.application.config.filter_parameters.map(&:to_s)
end
