namespace :zbmath_articles do
  desc "Import all zbMATH articles by month"
  task import_by_month: :environment do
    from_date = ENV["FROM_DATE"] || Date.current.beginning_of_month.strftime("%F")
    until_date = ENV["UNTIL_DATE"] || Date.current.end_of_month.strftime("%F")

    response = ZbmathArticle.import_by_month(from_date: from_date,
                                             until_date: until_date)
    puts response
  end

  desc "Import all zbMATH articles by day"
  task import_by_day: :environment do
    from_date = ENV["FROM_DATE"] || Date.current.strftime("%F")
    until_date = ENV["UNTIL_DATE"] || Date.current.strftime("%F")

    response = ZbmathArticle.import_by_day(from_date: from_date,
                                           until_date: until_date)
    puts response
  end

  desc "Import all zbMATH articles"
  task import: :environment do
    from_date = ENV["FROM_DATE"] || (Date.current - 1.day).strftime("%F")
    until_date = ENV["UNTIL_DATE"] || Date.current.strftime("%F")

    response = ZbmathArticle.import(from_date: from_date,
                                    until_date: until_date)
    puts "Queued import for #{response} zbMATH articles created from #{from_date} - #{until_date}."
  end
end
