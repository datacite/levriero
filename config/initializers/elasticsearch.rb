require 'faraday_middleware/aws_signers_v4'

if ENV['ES_HOST'] == "elasticsearch:9200"
  config = {
    host: ENV['ES_HOST'],
    transport_options: {
      request: { timeout: 5 }
    }
  }
  Elasticsearch::Persistence.client = Elasticsearch::Client.new(host: ENV['ES_HOST'], user: "elastic", password: ENV['ELASTIC_PASSWORD']) do |f|
    f.adapter Faraday.default_adapter
  end
else
  Elasticsearch::Persistence.client = Elasticsearch::Client.new(host: ENV['ES_HOST'], port: '80', scheme: 'http') do |f|
    f.request :aws_signers_v4,
      credentials: Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY']),
      service_name: 'es',
      region: ENV['AWS_REGION']

    f.adapter Faraday.default_adapter
  end
end
