class AffiliationIdentifier < Base
  LICENSE = "https://creativecommons.org/publicdomain/zero/1.0/".freeze

  include Queueable

  def self.import_by_month(options = {})
    from_date = (options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current).beginning_of_month
    until_date = (options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current).end_of_month

    # get first day of every month between from_date and until_date
    (from_date..until_date).select { |d| d.day == 1 }.each do |m|
      AffiliationIdentifierImportByMonthJob.perform_later(
        from_date: m.strftime("%F"), until_date: m.end_of_month.strftime("%F"),
      )
    end

    "Queued import for DOIs created from #{from_date.strftime('%F')} until #{until_date.strftime('%F')}."
  end

  def self.import(options = {})
    from_date = options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current - 1.day
    until_date = options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current

    name_identifier = AffiliationIdentifier.new
    name_identifier.queue_jobs(name_identifier.unfreeze(
                                 from_date: from_date.strftime("%F"), until_date: until_date.strftime("%F"),
                               ))
  end

  def source_id
    "datacite_affiliation"
  end

  def query
    "creators.affiliation.affiliationIdentifierScheme:ROR"
  end

  def push_data(result, _options = {})
    return result.body.fetch("errors") if result.body.fetch("errors",
                                                            nil).present?

    items = result.body.fetch("data", [])

    Array.wrap(items).map do |item|
      AffiliationIdentifierImportJob.perform_later(item)
    rescue Aws::SQS::Errors::InvalidParameterValue,
           Aws::SQS::Errors::RequestEntityTooLarge, Seahorse::Client::NetworkingError => e
      Rails.logger.error e.message
    end

    items.length
  end

  def self.push_item(item)
    # Do not link events for affiliations, return a count of zero
    0
  end

  def self.get_ror_metadata(id)
    return {} if id.blank?

    url = "https://api.ror.org/v2/organizations/#{id.delete_prefix('https://ror.org/')}"
    response = Maremma.get(url, host: true)
    return {} if response.status != 200

    message = response.body.fetch("data", {})

    # ROR v2 replaced the single "name" field with a "names" array.
    # Prefer long-form, human-readable names (type: "ror_display") over short forms like "EBI".
    # Fallback to "alias" or "primary" if no "ror_display" exists.

    name_entry = message["names"].find { |n| n["types"].include?("ror_display") } ||
                 message["names"].find { |n| n["types"].include?("alias") } ||
                 message["names"].find { |n| n["types"].include?("primary") } ||
                 message["names"].first

    location = {
      "type" => "postalAddress",
      "addressCountry" => message.dig("locations", 0, "geonames_details", "country_name"),
    }

    {
      "@id" => id,
      "@type" => "Organization",
      "name" => name_entry&.dig("value"),
      "location" => location,
    }.compact
  end
end
