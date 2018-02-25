require 'faraday_middleware/aws_sigv4'
require 'net/http/persistent'

if ENV['ES_HOST'] == "elasticsearch:9200"
  config = {
    host: ENV['ES_HOST'],
    transport_options: {
      request: { timeout: 5 }
    }
  }
  Elasticsearch::Persistence.client = Elasticsearch::Client.new(host: ENV['ES_HOST'], user: "elastic", password: ENV['ELASTIC_PASSWORD']) do |f|
    f.adapter :net_http_persistent
  end
else
  Elasticsearch::Persistence.client = Elasticsearch::Client.new(host: ENV['ES_HOST']) do |f|
    f.request :aws_sigv4,
      credentials: Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY']),
      service: 'es',
      region: ENV['AWS_REGION']

    f.adapter :net_http_persistent
  end
end
