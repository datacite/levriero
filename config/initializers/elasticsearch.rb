require 'faraday_middleware/aws_sigv4'

if ENV['ES_HOST'] == "elasticsearch:9200"
  config = {
    host: ENV['ES_HOST'],
    transport_options: {
      request: { timeout: 5 }
    }
  }
  Elasticsearch::Persistence.client = Elasticsearch::Client.new(host: ENV['ES_HOST'], user: "elastic", password: ENV['ELASTIC_PASSWORD'], log: ENV['LOG_LEVEL'] == "debug")
else
  Elasticsearch::Persistence.client = Elasticsearch::Client.new(host: ENV['ES_HOST']) do |f|
    f.request :aws_sigv4,
      credentials: Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY']),
      service: 'es',
      region: ENV['AWS_REGION']

    f.response :logger
    f.adapter  Faraday.default_adapter
  end
end
