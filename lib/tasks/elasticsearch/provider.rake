namespace :elasticsearch do
  namespace :provider do
    desc 'Import all providers'
    task :import => :environment do
      Provider.import_from_api
    end

    desc "Create index for providers"
    task :create_index => :environment do
      Provider.__elasticsearch__.create_index!
    end

    desc "Delete index for providers"
    task :delete_index => :environment do
      Provider.__elasticsearch__.delete_index!
    end

    desc "Refresh index for providers"
    task :refresh_index => :environment do
      Provider.__elasticsearch__.refresh_index!
    end
  end
end
