class AffiliationIdentifier < Base
  LICENSE = "https://creativecommons.org/publicdomain/zero/1.0/"

  def self.import_by_month(options={})
    from_date = (options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current).beginning_of_month
    until_date = (options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current).end_of_month

    # get first day of every month between from_date and until_date
    (from_date..until_date).select {|d| d.day == 1}.each do |m|
      AffiliationIdentifierImportByMonthJob.perform_later(from_date: m.strftime("%F"), until_date: m.end_of_month.strftime("%F"))
    end

    "Queued import for DOIs created from #{from_date.strftime("%F")} until #{until_date.strftime("%F")}."
  end

  def self.import(options={})
    from_date = options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current - 1.day
    until_date = options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current

    name_identifier = AffiliationIdentifier.new
    name_identifier.queue_jobs(name_identifier.unfreeze(from_date: from_date.strftime("%F"), until_date: until_date.strftime("%F")))
  end

  def source_id
    "datacite_affiliation"
  end

  def query
    "creators.affiliation.affiliationIdentifierScheme:ROR"
  end

  def push_data(result, options={})
    logger = Logger.new(STDOUT)
    return result.body.fetch("errors") if result.body.fetch("errors", nil).present?

    items = result.body.fetch("data", [])

    Array.wrap(items).map do |item|
      begin
        AffiliationIdentifierImportJob.perform_later(item)
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
    doi = attributes.fetch("doi", nil)
    return nil unless doi.present?

    pid = normalize_doi(doi)
    related_identifiers = Array.wrap(attributes.fetch("relatedIdentifiers", nil))
    skip_doi = related_identifiers.any? do |related_identifier|
      ["IsIdenticalTo", "IsPartOf", "IsPreviousVersionOf"].include?(related_identifier["relatedIdentifierType"])
    end
    creators = attributes.fetch("creators", []).select { |n| Array.wrap(n.fetch("nameIdentifiers", nil)).any? { |n| n["nameIdentifierScheme"] == "ORCID" } }
    return nil if creators.blank? || skip_doi

    source_id = item.fetch("sourceId", "datacite_affiliation")
    relation_type_id = "is_authored_at"
    source_token = ENV['DATACITE_AFFILIATION_SOURCE_TOKEN']
    
    push_items = Array.wrap(creators).select { |c| c.dig("affiliation", "affiliationIdentifierScheme") == "ROR" }.map do |iitem|
      obj_id = normalize_ror(iitem.dig("affiliation", "affiliationIdentifier"))

      if obj_id.present?
        subj = cached_datacite_response(pid)
        obj = cached_orcid_response(obj_id)

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

    # there can be one or more name_identifier per DOI
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

      # send to Profiles service, which then pushes to ORCID
      if ENV['VOLPINO_TOKEN'].present?
        push_url = ENV['VOLPINO_URL'] + "/claims"
        doi = doi_from_url(iiitem["subj_id"])
        orcid = orcid_from_url(iiitem["obj_id"])
        source_id = iiitem["source_id"] == "datacite_orcid_auto_update" ? "orcid_update" : "orcid_search"

        data = { 
          "claim" => {
            "doi" => doi,
            "orcid" => orcid,
            "source_id" => source_id,
            "claim_action"=> "create" }}

        response = Maremma.post(push_url, data: data.to_json,
                                          bearer: ENV['VOLPINO_TOKEN'],
                                          content_type: 'application/json')
                                        
        if response.status == 202
          logger.info "[Profiles] claim ORCID ID #{orcid} for DOI #{doi} pushed to Profiles service."
        elsif response.status == 409
          logger.info "[Profiles] claim ORCID ID #{orcid} for DOI #{doi} already pushed to Profiles service."
        elsif response.body["errors"].present?
          logger.info "[Profiles] claim ORCID ID #{orcid} for DOI #{doi} had an error: #{response.body['errors'].first['title']}"
        end
      end
    end

    push_items.length
  end
end
