class ImportProviderJob < ActiveJob::Base
  queue_as :default

  rescue_from ActiveJob::DeserializationError, Faraday::TimeoutError do
    retry_job wait: 5.minutes, queue: :default
  end

  def perform
    Provider.import_from_api
  end
end
