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
    attributes = item.fetch("attributes", {})
    doi = attributes.fetch("doi", nil)
    return nil if doi.blank?

    pid = normalize_doi(doi)
    funder_identifiers = Array.wrap(attributes.fetch("fundingReferences",
                                                     nil)).select do |f|
      f["funderIdentifierType"] == "Crossref Funder ID"
    end

    push_items = Array.wrap(funder_identifiers).reduce([]) do |ssum, iitem|
      funder_identifier = iitem.fetch("funderIdentifier",
                                      nil).to_s.strip.downcase
      obj_id = normalize_doi(funder_identifier)

      relation_type_id = "is_funded_by"
      source_id = "datacite_funder"
      source_token = ENV["DATACITE_FUNDER_SOURCE_TOKEN"]

      if funder_identifier.present? && obj_id.present?
        subj = cached_datacite_response(pid)
        obj = cached_funder_response(obj_id)

        ssum << { "message_action" => "create",
                  "subj_id" => pid,
                  "obj_id" => obj_id,
                  "relation_type_id" => relation_type_id,
                  "source_id" => source_id,
                  "source_token" => source_token,
                  "occurred_at" => attributes.fetch("updated"),
                  "timestamp" => Time.zone.now.iso8601,
                  "license" => LICENSE,
                  "subj" => subj,
                  "obj" => obj }
      end

      ssum
    end

    # there can be one or more funder_identifier per DOI
    Array.wrap(push_items).each do |iiitem|
      data = {
        "data" => {
          "type" => "events",
          "attributes" => {
            "messageAction" => iiitem["message_action"],
            "subjId" => iiitem["subj_id"],
            "objId" => iiitem["obj_id"],
            "relationTypeId" => iiitem["relation_type_id"].to_s.dasherize,
            "sourceId" => iiitem["source_id"].to_s.dasherize,
            "sourceToken" => iiitem["source_token"],
            "occurredAt" => iiitem["occurred_at"],
            "timestamp" => iiitem["timestamp"],
            "license" => iiitem["license"],
            "subj" => iiitem["subj"],
            "obj" => iiitem["obj"],
          },
        },
      }

      send_event_import_message(data)

      Rails.logger.info "[Event Data] #{iiitem['subj_id']} #{iiitem['relation_type_id']} #{iiitem['obj_id']} sent to the events queue."
    end

    push_items.length
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
