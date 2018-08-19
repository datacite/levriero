namespace :related_url do
  desc 'Import all related_urls by month'
  task :import_by_month => :environment do
    from_date = ENV['FROM_DATE'] || Date.current.beginning_of_month.strftime("%F")
    until_date = ENV['UNTIL_DATE'] || Date.current.end_of_month.strftime("%F")

    response = RelatedUrl.import_by_month(from_date: from_date, until_date: until_date)
    puts response
  end

  desc 'Import all related_urls'
  task :import => :environment do
    from_date = ENV['FROM_DATE'] || (Date.current - 1.day).strftime("%F")
    until_date = ENV['UNTIL_DATE'] || Date.current.strftime("%F")

    response = RelatedUrl.import(from_date: from_date, until_date: until_date)
    puts "Queued import for #{response} DOIs updated from #{from_date} - #{until_date}."
  end
end