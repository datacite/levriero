## https://github.com/elastic/elasticsearch-ruby/issues/462
RSpec.configure do |config|
  config.before :suite, elasticsearch: true do
    # Elasticsearch::Persistence.client = Elasticsearch::Client.new host: 'http://localhost:9200', tracer: true
    # Elasticsearch::Persistence.client = Elasticsearch::Client.new host: "elasticsearch-test:9250"
    Elasticsearch::Persistence.client = Elasticsearch::Client.new host: ENV['ES_HOST']
    sleep 5
  end
#
# # spec/spec_helper.rb
# require 'elasticsearch/extensions/test/cluster'
#
# RSpec.configure do |config|
#   # Start an in-memory cluster for Elasticsearch as needed
#   # config.before :all, elasticsearch: true do
#   config.before :all, elasticsearch: true do
#     Elasticsearch::Extensions::Test::Cluster.start(command: "/usr/share/elasticsearch-5.6.4/bin/elasticsearch", host: 'localhost', port: 9250, nodes: 1, timeout: 120) unless Elasticsearch::Extensions::Test::Cluster.running?(on: 9250)
#   end
#
#   # Stop elasticsearch cluster after test run
#   config.after :suite do
#     Elasticsearch::Extensions::Test::Cluster.stop(command: "/usr/share/elasticsearch-5.6.4/bin/elasticsearch", host: 'localhost', port: 9250, nodes: 1) if Elasticsearch::Extensions::Test::Cluster.running?(on: 9250)
#   end
# # end
# #
#
#
# config.around :each, elasticsearch: true do |example|
#   # Elasticsearch::Persistence::Model.each do |model|
#     # Provider.__elasticsearch__.create_index!(force: true)
#     # Provider.__elasticsearch__.refresh_index!
#   # end

#   example.run

#   # Elasticsearch::Persistence::Model.each do |model|
#     Provider.__elasticsearch__.client.indices.delete index: model.index_name
#   # end
# end


config.before :all, elasticsearch: true do

end

config.after :all, elasticsearch: true do
  # Maremma.delete("elasticsearch-test:9250/_all")
  Maremma.delete("http://"+ENV['ES_HOST']+"/_all")
end

#
# # # spec/spec_helper.rb
# # RSpec.configure do |config|
#   # Create indexes for all elastic searchable models
  # config.before :each, elasticsearch: true do
  #   Elasticsearch::Persistence::Model.descendants.each do |model|
  #     if model.respond_to?(:__elasticsearch__)
  #       begin
  #         model.__elasticsearch__.create_index!
  #         model.__elasticsearch__.refresh_index!
  #       rescue => Elasticsearch::Transport::Transport::Errors::NotFound
  #         # This kills "Index does not exist" errors being written to console
  #         # by this: https://github.com/elastic/elasticsearch-rails/blob/738c63efacc167b6e8faae3b01a1a0135cfc8bbb/elasticsearch-model/lib/elasticsearch/model/indexing.rb#L268
  #       rescue => e
  #         STDERR.puts "There was an error creating the elasticsearch index for #{model.name}: #{e.inspect}"
  #       end
  #     end
  #   end
  # end
#
#   # Delete indexes for all elastic searchable models to ensure clean state between tests
#   config.after :each, elasticsearch: true do
#     Elasticsearch::Persistence::Model.descendants.each do |model|
#       if model.respond_to?(:__elasticsearch__)
#         begin
#           model.__elasticsearch__.delete_index!
#         rescue => Elasticsearch::Transport::Transport::Errors::NotFound
#           # This kills "Index does not exist" errors being written to console
#           # by this: https://github.com/elastic/elasticsearch-rails/blob/738c63efacc167b6e8faae3b01a1a0135cfc8bbb/elasticsearch-model/lib/elasticsearch/model/indexing.rb#L268
#         rescue => e
#           STDERR.puts "There was an error removing the elasticsearch index for #{model.name}: #{e.inspect}"
#         end
#       end
#     end
#   end
end
