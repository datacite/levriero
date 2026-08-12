class FunderIdentifier < Base
  LICENSE = "https://creativecommons.org/publicdomain/zero/1.0/".freeze

  include Queueable

  def self.import_by_month(options = {})
    from_date = (options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current).beginning_of_month
    until_date = (options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current).end_of_month

    # get first day of every month between from_date and until_date
    (from_date..until_date).select { |d| d.day == 1 }.each do |m|
      FunderIdentifierImportByMonthJob.perform_later(
        from_date: m.strftime("%F"), until_date: m.end_of_month.strftime("%F"),
      )
    end

    "Queued import for DOIs created from #{from_date.strftime('%F')} until #{until_date.strftime('%F')}."
  end

  def self.import(options = {})
    from_date = options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current - 1.day
    until_date = options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current

    funder_identifier = FunderIdentifier.new
    funder_identifier.queue_jobs(funder_identifier.unfreeze(
                                   from_date: from_date.strftime("%F"), until_date: until_date.strftime("%F"),
                                 ))
  end

  def source_id
    "datacite_funder"
  end

  def query
    "fundingReferences.funderIdentifierType:\"Crossref Funder ID\""
  end

  def push_data(result, _options = {})
    return result.body.fetch("errors") if result.body.fetch("errors",
                                                            nil).present?

    items = result.body.fetch("data", [])
    # Rails.logger.info "Extracting funder identifiers for #{items.size} DOIs updated from #{options[:from_date]} until #{options[:until_date]}."

    Array.wrap(items).map do |item|
      FunderIdentifierImportJob.perform_later(item)
    rescue Aws::SQS::Errors::InvalidParameterValue,
           Aws::SQS::Errors::RequestEntityTooLarge, Seahorse::Client::NetworkingError => e
      Rails.logger.error e.message
    end

    items.length
  end

  def self.push_item(item)
    # Do not link events for funders, return a count of zero
    0
  end

  def self.get_funder_metadata(id)
    doi = doi_from_url(id)
    url = "https://api.crossref.org/funders/#{doi}"
    response = Maremma.get(url, host: true)

    return {} if response.status != 200

    message = response.body.dig("data", "message")

    location = if message["location"].present?
                 {
                   "type" => "postalAddress",
                   "addressCountry" => message["location"],
                 }
               end

    {
      "@id" => id,
      "@type" => "Funder",
      "name" => message["name"],
      "alternateName" => message["alt-names"],
      "location" => location,
      "dateModified" => "2018-07-11T00:00:00Z",
    }.compact
  end
end
