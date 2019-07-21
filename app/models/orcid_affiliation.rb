class OrcidAffiliation < Base
  LICENSE = "https://creativecommons.org/publicdomain/zero/1.0/"

  def self.import_by_month(options={})
    from_date = (options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current).beginning_of_month
    until_date = (options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current).end_of_month

    # get first day of every month between from_date and until_date
    (from_date..until_date).select {|d| d.day == 1}.each do |m|
      OrcidAffiliationImportByMonthJob.perform_later(from_date: m.strftime("%F"), until_date: m.end_of_month.strftime("%F"))
    end

    "Queued import for DOIs created from #{from_date.strftime("%F")} until #{until_date.strftime("%F")}."
  end

  def self.import(options={})
    from_date = options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current - 1.day
    until_date = options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current

    orcid_affiliation = OrcidAffiliation.new
    orcid_affiliation.queue_jobs(orcid_affiliation.unfreeze(from_date: from_date.strftime("%F"), until_date: until_date.strftime("%F")))
  end

  def source_id
    "orcid_affiliation"
  end

  def query
    "creators.nameIdentifiers.nameIdentifierScheme:ORCID +creators.affiliation.affiliationIdentifierScheme:ROR"
  end

  def push_data(result, options={})
    logger = Logger.new(STDOUT)
    return result.body.fetch("errors") if result.body.fetch("errors", nil).present?

    items = result.body.fetch("data", [])

    Array.wrap(items).map do |item|
      begin
        OrcidAffiliationImportJob.perform_later(item)
      rescue Aws::SQS::Errors::InvalidParameterValue, Aws::SQS::Errors::RequestEntityTooLarge, Seahorse::Client::NetworkingError => error
        logger = Logger.new(STDOUT)
        logger.error error.message
      end
    end

    items.length
  end

  def self.push_item(item)
    logger = Logger.new(STDOUT)

    attributes = item.fetch("attributes", {})
    related_identifiers = Array.wrap(attributes.fetch("relatedIdentifiers", nil))
    skip_doi = related_identifiers.any? do |related_identifier|
      ["IsIdenticalTo", "IsPartOf", "IsPreviousVersionOf", "IsVersionOf"].include?(related_identifier["relatedIdentifierType"])
    end

    total_push_items = []

    attributes.fetch("creators", []).map do |creator|
      name_identifier = Array.wrap(creator.fetch("nameIdentifiers", nil)).find { |n| n["nameIdentifierScheme"] == "ORCID" }
      skip_orcid = name_identifier.blank?

      affiliation_identifiers = Array.wrap(creator).reduce([]) do |sum, c| 
        Array.wrap(c["affiliation"]).each do |a|
          sum << a["affiliationIdentifier"] if a["affiliationIdentifierScheme"] == "ROR"
        end

        sum
      end

      return nil if affiliation_identifiers.blank? || skip_doi || skip_orcid

      subj_id = normalize_orcid(name_identifier["nameIdentifier"])
      source_id = item.fetch("sourceId", "orcid_affiliation")
      relation_type_id = "is_affiliated_with"
      source_token = ENV['ORCID_AFFILIATION_SOURCE_TOKEN']
      
      push_items = Array.wrap(affiliation_identifiers).reduce([]) do |ssum, iitem|
        obj_id = normalize_ror(iitem)

        if obj_id.present?
          subj = cached_orcid_response(subj_id)
          obj = cached_ror_response(obj_id)

          ssum << { "message_action" => "create",
                    "subj_id" => subj_id,
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
        if ENV['LAGOTTINO_TOKEN'].present?
          push_url = ENV['LAGOTTINO_URL'] + "/events"

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
                "obj" => iiitem["obj"] } }}

          response = Maremma.post(push_url, data: data.to_json,
                                            bearer: ENV['LAGOTTINO_TOKEN'],
                                            content_type: 'application/vnd.api+json',
                                            accept: 'application/vnd.api+json; version=2')

          if [200, 201].include?(response.status)
            logger.info "[Event Data] #{iiitem['subj_id']} #{iiitem['relation_type_id']} #{iiitem['obj_id']} pushed to Event Data service."
          elsif response.status == 409
            logger.info "[Event Data] #{iiitem['subj_id']} #{iiitem['relation_type_id']} #{iiitem['obj_id']} already pushed to Event Data service."
          elsif response.body["errors"].present?
            logger.error "[Event Data] #{iiitem['subj_id']} #{iiitem['relation_type_id']} #{iiitem['obj_id']} had an error: #{response.body['errors'].first['title']}"
            logger.error data.inspect
          end
        end
      end

      total_push_items += push_items
    end

    total_push_items.length
  end

  def self.get_ror_metadata(id)
    return {} unless id.present?

    url = "https://api.ror.org/organizations/" + id[8..-1]
    response = Maremma.get(url, host: true)
    return {} if response.status != 200

    message = response.body.fetch("data", {})
    
    location = { 
      "type" => "postalAddress",
      "addressCountry" => message.dig("country", "country_name")
    }
    
    {
      "@id" => id,
      "@type" => "Organization",
      "name" => message["name"],
      "location" => location }.compact
  end
end
