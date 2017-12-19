require 'elasticsearch/rails/tasks/import'


namespace :elasticsearch do
  namespace :re_index do
    desc "Re-index all models"
    task :all => :environment do
      Provider.__elasticsearch__.create_index! force: true
      Provider.__elasticsearch__.import do |response|
        puts "Got " + response['items'].select { |i| i['index']['error'] }.size.to_s + " errors"
      end

      Client.__elasticsearch__.create_index! force: true
      Client.__elasticsearch__.import do |response|
        puts "Got " + response['items'].select { |i| i['index']['error'] }.size.to_s + " errors"
      end
    end
  end

  namespace :create_index do
    desc "Create indexes"
    task :all => :environment do
      puts Provider.respond_to?(:__elasticsearch__)
      puts Provider.respond_to?(:create_index)
      puts Provider.respond_to?(:__elasticsearch__)
      puts Provider.respond_to?(:__elasticsearch__)
      # Provider.__elasticsearch__.create_index! force: true
      # Client.__elasticsearch__.create_index! force: true


      # Elasticsearch::Persistence::Model.descendants.each do |model|
      #   if model.respond_to?(:__elasticsearch__)
      #     begin
      #       model.__elasticsearch__.create_index!
      #       model.__elasticsearch__.refresh_index!
      #     rescue => Elasticsearch::Transport::Transport::Errors::NotFound
      #       # This kills "Index does not exist" errors being written to console
      #       # by this: https://github.com/elastic/elasticsearch-rails/blob/738c63efacc167b6e8faae3b01a1a0135cfc8bbb/elasticsearch-model/lib/elasticsearch/model/indexing.rb#L268
      #     rescue => e
      #       STDERR.puts "There was an error creating the elasticsearch index for #{model.name}: #{e.inspect}"
      #     end
      #   end
      # end


    end
  end

  namespace :start_dummy_index do
    desc "Create indexes"
    task :all => :environment do
      require 'factory_bot'
      require File.expand_path("spec/factories/default.rb")

      providers = FactoryBot.build_list(:provider, 25) 
      provider = providers.first 
      clients = FactoryBot.build_list(:client, 10, provider_id: provider.symbol) 

      providers.each { |item| Provider.create(item) }
      clients.each   { |item| Client.create(item) }
    end
  end

  namespace :delete_index do
    desc "Delete indexes"
    task :all => :environment do
      es_client = Elasticsearch::Client.new host: ENV['ES_HOST']
      es_client.indices.delete index: ['providers', 'provider','provider_services','dois',]
    end
  end
end
