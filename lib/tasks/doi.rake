namespace :doi do
  desc 'Import all dois'
  task :import => :environment do
    from_date = ENV['FROM_DATE'] || Date.current.beginning_of_month
    until_date = ENV['UNTIL_DATE'] || Date.current.end_of_month

    Doi.import_by_month(from_date: from_date, until_date: until_date)
  end
end