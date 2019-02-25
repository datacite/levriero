class RelatedUrl < Base
  LICENSE = "https://creativecommons.org/publicdomain/zero/1.0/"

  def self.import_by_month(options={})
    from_date = (options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current).beginning_of_month
    until_date = (options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current).end_of_month

    # get first day of every month between from_date and until_date
    (from_date..until_date).select {|d| d.day == 1}.each do |m|
      RelatedUrlImportByMonthJob.perform_later(from_date: m.strftime("%F"), until_date: m.end_of_month.strftime("%F"))
    end

    "Queued import for DOIs updated from #{from_date.strftime("%F")} until #{until_date.strftime("%F")}."
  end

  def self.import(options={})
    from_date = options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current - 1.day
    until_date = options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current

    related_url = RelatedUrl.new
    related_url.queue_jobs(related_url.unfreeze(from_date: from_date.strftime("%F"), until_date: until_date.strftime("%F")))
  end

  def source_id
    "datacite_url"
  end

  def query
    "relatedIdentifiers.relatedIdentifierType:URL"
  end

  def push_data(result, options={})
    return result.body.fetch("errors") if result.body.fetch("errors", nil).present?

    items = result.body.fetch("data", [])
    
    Array.wrap(items).map do |item|
      begin
        RelatedUrlImportJob.perform_later(item)
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
    related_urls = Array.wrap(attributes.fetch("relatedIdentifiers", nil)).select { |r| r["relatedIdentifierType"] == "URL" }
    push_items = Array.wrap(related_urls).reduce([]) do |ssum, iitem|
      related_url = iitem.fetch("relatedIdentifier", nil).to_s.strip.downcase
      obj_id = normalize_url(related_url)
      source_id = "datacite_url"
      source_token = ENV['DATACITE_URL_SOURCE_TOKEN']

      # only create event if valid http/https/ftp URL
      if obj_id.present?
        subj = cached_datacite_response(pid)

        ssum << { "message_action" => "create",
                  "subj_id" => pid,
                  "obj_id" => obj_id,
                  "relation_type_id" => iitem["relationType"].to_s.underscore,
                  "source_id" => source_id,
                  "source_token" => source_token,
                  "occurred_at" => attributes.fetch("updated"),
                  "timestamp" => Time.zone.now.iso8601,
                  "license" => LICENSE,
                  "subj" => subj,
                  "obj" => {} }
      end
      
      ssum
    end

    # there can be one or more related_url per DOI
    Array.wrap(push_items).each do |iiitem|
      # send to DataCite Event Data Query API
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
          logger.info "[Event Data] #{iiitem['subj_id']} #{iiitem['relation_type_id']} #{iiitem['obj_id']} had an error: #{response.body['errors'].first['title']}"
        end
      end
    end

    push_items.length
  end
end
