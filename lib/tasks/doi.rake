namespace :doi do
  desc 'Store handle URL'
  task :set_url => :environment do
    from_date = ENV['FROM_DATE'] || Time.zone.now - 1.day
    Doi.where(url: nil).where("updated >= ?", from_date).find_each do |doi|
      UrlJob.perform_later(doi)
    end
  end
end