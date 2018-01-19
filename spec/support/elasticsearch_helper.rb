## https://github.com/elastic/elasticsearch-ruby/issues/462
RSpec.configure do |config|
  config.before :suite, elasticsearch: true do

    Elasticsearch::Persistence.client = Elasticsearch::Client.new host: ENV['ES_HOST']
    sleep 5
  end

  config.before :all, elasticsearch: true do

  end

  config.after :all, elasticsearch: true do
    Maremma.delete("http://"+ENV['ES_HOST']+"/_all")
  end

end
