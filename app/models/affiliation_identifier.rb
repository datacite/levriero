class AffiliationIdentifier < Base
  LICENSE = "https://creativecommons.org/publicdomain/zero/1.0/".freeze

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
    attributes = item.fetch("attributes", {})
    doi = attributes.fetch("doi", nil)
    return nil if doi.blank?

    pid = normalize_doi(doi)
    related_identifiers = Array.wrap(attributes.fetch("relatedIdentifiers",
                                                      nil))
    skip_doi = related_identifiers.any? do |related_identifier|
      ["IsIdenticalTo", "IsPartOf", "IsPreviousVersionOf",
       "IsVersionOf"].include?(related_identifier["relatedIdentifierType"])
    end

    affiliation_identifiers = attributes.fetch("creators",
                                               []).reduce([]) do |sum, c|
      Array.wrap(c["affiliation"]).each do |a|
        sum << a["affiliationIdentifier"] if a["affiliationIdentifierScheme"] == "ROR"
      end

      sum
    end

    return nil if affiliation_identifiers.blank? || skip_doi

    source_id = item.fetch("sourceId", "datacite_affiliation")
    relation_type_id = "is_authored_at"
    source_token = ENV["DATACITE_AFFILIATION_SOURCE_TOKEN"]

    push_items = Array.wrap(affiliation_identifiers).reduce([]) do |ssum, iitem|
      obj_id = normalize_ror(iitem)

      if obj_id.present?
        subj = cached_datacite_response(pid)
        obj = cached_ror_response(obj_id)

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

    # there can be one or more affiliation_identifier per DOI
    Array.wrap(push_items).each do |iiitem|
      # send to DataCite Event Data API
      if ENV["STAFF_ADMIN_TOKEN"].present?
        push_url = "#{ENV['LAGOTTINO_URL']}/events"

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

        response = Maremma.post(push_url, data: data.to_json,
                                          bearer: ENV["STAFF_ADMIN_TOKEN"],
                                          content_type: "application/vnd.api+json",
                                          accept: "application/vnd.api+json; version=2")

        if [200, 201].include?(response.status)
          Rails.logger.info "[Event Data] #{iiitem['subj_id']} #{iiitem['relation_type_id']} #{iiitem['obj_id']} pushed to Event Data service."
        elsif response.status == 409
          Rails.logger.info "[Event Data] #{iiitem['subj_id']} #{iiitem['relation_type_id']} #{iiitem['obj_id']} already pushed to Event Data service."
        elsif response.body["errors"].present?
          Rails.logger.error "[Event Data] #{iiitem['subj_id']} #{iiitem['relation_type_id']} #{iiitem['obj_id']} had an error: #{response.body['errors']}"
          Rails.logger.error data.inspect
        end
      end
    end

    push_items.length
  end

  def self.get_ror_metadata(id)
    return {} if id.blank?

    url = "https://api.ror.org/organizations/#{id[8..]}"
    response = Maremma.get(url, host: true)
    return {} if response.status != 200

    message = response.body.fetch("data", {})

    location = {
      "type" => "postalAddress",
      "addressCountry" => message.dig("country", "country_name"),
    }

    {
      "@id" => id,
      "@type" => "Organization",
      "name" => message["name"],
      "location" => location,
    }.compact
  end
end
