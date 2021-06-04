namespace :name_identifier do
  desc "Import all name_identifiers by month"
  task import_by_month: :environment do
    from_date = ENV["FROM_DATE"] || Date.current.beginning_of_month.strftime("%F")
    until_date = ENV["UNTIL_DATE"] || Date.current.end_of_month.strftime("%F")

    response = NameIdentifier.import_by_month(from_date: from_date,
                                              until_date: until_date)
    puts response
  end

  desc "Import all name_identifiers"
  task import: :environment do
    from_date = ENV["FROM_DATE"] || (Date.current - 1.day).strftime("%F")
    until_date = ENV["UNTIL_DATE"] || Date.current.strftime("%F")

    response = NameIdentifier.import(from_date: from_date,
                                     until_date: until_date)
    puts "Queued import for #{response} DOIs created from #{from_date} - #{until_date}."
  end

  task import_one: :environment do
    if ENV["DOI"].nil?
      puts "ENV['DOI'] is required."
      exit
    end

    response = NameIdentifier.import_one(doi: ENV["DOI"])
    puts "Import for #{response} DOI #{ENV['DOI']}"
  end
end
