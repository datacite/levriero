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
      Provider.recreate_index force: true
      Client.recreate_index force: true
  

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
      es_client.indices.delete index: ['providers','clients']
    end
  end
end
