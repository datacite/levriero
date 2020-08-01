namespace :usage_update do
  desc 'Import all usage_updates by year'
  task :import_by_year => :environment do
    from_date = ENV['FROM_DATE'] || Date.current.beginning_of_year.strftime("%F")
    until_date = ENV['UNTIL_DATE'] || Date.current.end_of_year.strftime("%F")

    response = UsageUpdate.import_by_year(from_date: from_date, until_date: until_date)
    puts response
  end

end