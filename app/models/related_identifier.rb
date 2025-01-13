class RelatedIdentifier < Base
  LICENSE = "https://creativecommons.org/publicdomain/zero/1.0/".freeze
  DATACITE_CROSSREF = "datacite_crossref"

  include Helpable
  include Cacheable
  include Queueable

  def self.import_by_month(options = {})
    from_date = (options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current).beginning_of_month
    until_date = (options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current).end_of_month
    resource_type_id = options[:resource_type_id].present? || ""

    # get first day of every month between from_date and until_date
    (from_date..until_date).select { |d| d.day == 1 }.each do |m|
      RelatedIdentifierImportByMonthJob.perform_later(
        from_date: m.strftime("%F"), until_date: m.end_of_month.strftime("%F"), resource_type_id: resource_type_id,
      )
    end

    "Queued import for DOIs created from #{from_date.strftime('%F')} until #{until_date.strftime('%F')}."
  end

  def self.import(options = {})
    from_date = options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current - 1.day
    until_date = options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current
    resource_type_id = options[:resource_type_id].present? || ""

    related_identifier = RelatedIdentifier.new
    related_identifier.queue_jobs(related_identifier.unfreeze(
                                    from_date: from_date.strftime("%F"), until_date: until_date.strftime("%F"), resource_type_id: resource_type_id,
                                  ))
  end

  def source_id
    "datacite_related"
  end

  def query
    "relatedIdentifiers.relatedIdentifierType:DOI"
  end

  def push_data(result, _options = {})
    return result.body.fetch("errors") if result.body.fetch("errors",
                                                            nil).present?

    items = result.body.fetch("data", [])
    # Rails.logger.info "Extracting related identifiers for #{items.size} DOIs created from #{options[:from_date]} until #{options[:until_date]}."

    Array.wrap(items).map do |item|
      RelatedIdentifierImportJob.perform_later(item)
    rescue Aws::SQS::Errors::InvalidParameterValue,
           Aws::SQS::Errors::RequestEntityTooLarge, Seahorse::Client::NetworkingError => e
      Rails.logger.error e.message
    end

    items.length
  end

  def self.push_item(item)
    Rails.logger.info("Related Identifier: push_item start")
    attributes = item.fetch("attributes", {})
    Rails.logger.info("Related Identifier: attributes -> #{attributes.inspect}")
    doi = attributes.fetch("doi", nil)
    Rails.logger.info("Related Identifier: doi -> #{doi.inspect}")

    if doi.blank?
      Rails.logger.info("[Related Identifier: doi is blank]")
    end

    if cached_doi_ra(doi) == "DataCite"
      Rails.logger.info("[Related Identifier: doi is #{cached_doi_ra(doi)}]")
      Rails.logger.info("[Related Identifier: cached doi ra is datacite]")
    end

    return nil unless doi.present? && cached_doi_ra(doi) == "DataCite"

    pid = normalize_doi(doi)

    related_doi_identifiers = Array.wrap(attributes.fetch("relatedIdentifiers", nil)).select do |r|
      r["relatedIdentifierType"] == "DOI"
    end

    registration_agencies = {}

    push_items = Array.wrap(related_doi_identifiers).reduce([]) do |ssum, iitem|
      related_identifier = iitem.fetch("relatedIdentifier", nil).to_s.strip.downcase
      obj_id = normalize_doi(related_identifier)
      prefix = validate_prefix(related_identifier)

      unless registration_agencies[prefix]
        registration_agencies[prefix] = cached_doi_ra(related_identifier)
      end

      if registration_agencies[prefix].nil?
        Rails.logger.error "No DOI registration agency for DOI #{related_identifier} found."
        source_id = "datacite_related"
        source_token = ENV["DATACITE_RELATED_SOURCE_TOKEN"]
        obj = {}
      elsif registration_agencies[prefix] == "DataCite"
        source_id = "datacite_related"
        source_token = ENV["DATACITE_RELATED_SOURCE_TOKEN"]
        obj = cached_datacite_response(obj_id)
      elsif registration_agencies[prefix] == "Crossref"
        source_id = DATACITE_CROSSREF
        source_token = ENV["DATACITE_CROSSREF_SOURCE_TOKEN"]
        obj = cached_crossref_response(obj_id)
      elsif registration_agencies[prefix].present?
        source_id = "datacite_#{registration_agencies[prefix].downcase}"
        source_token = ENV["DATACITE_OTHER_SOURCE_TOKEN"]
        obj = {}
      end

      if registration_agencies[prefix].present? && obj_id.present?
        subj = cached_datacite_response(pid)

        ssum << { "message_action" => "create",
                  "id" => SecureRandom.uuid,
                  "subj_id" => pid,
                  "obj_id" => obj_id,
                  "relation_type_id" => iitem["relationType"].to_s.underscore,
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

    Rails.logger.info("[Related Identifier]: push items count is #{push_items.length}")

    # there can be one or more related_identifier per DOI
    Array.wrap(push_items).each do |iiitem|
      data = {
        "data" => {
          "type" => "events",
          "id" => iiitem["id"],
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

      Rails.logger.info("[Related Identifier]: pushed to queue data")
      Rails.logger.info("[Related Identifier]: #{data}")
      send_event_import_message(data)

      Rails.logger.info "[Event Data] #{iiitem['subj_id']} #{iiitem['relation_type_id']} #{iiitem['obj_id']} sent to the events queue."

      # send to Event Data Bus
      # we only send datacite_crossref events to the bus
      if ENV["EVENTDATA_TOKEN"].present? && iiitem['source_id'] == DATACITE_CROSSREF
        iiitem = set_event_for_bus(iiitem)

        host = ENV["EVENTDATA_URL"]
        push_url = "#{host}/events"
        response = Maremma.post(push_url, data: iiitem.to_json,
                                          bearer: ENV["EVENTDATA_TOKEN"],
                                          content_type: "json",
                                          host: host)

        # return 0 if successful, 1 if error
        if response.status == 201
          Rails.logger.info "[Event Data Bus] #{iiitem['subj_id']} #{iiitem['relation_type_id']} #{iiitem['obj_id']} pushed to Event Data service."
        elsif response.status == 409
          Rails.logger.info "[Event Data Bus] #{iiitem['subj_id']} #{iiitem['relation_type_id']} #{iiitem['obj_id']} already pushed to Event Data service."
        elsif response.body["errors"].present?
          Rails.logger.error "[Event Data Bus] #{iiitem['subj_id']} #{iiitem['relation_type_id']} #{iiitem['obj_id']} had an error:"
          Rails.logger.error "[Event Data Bus] #{response.body['errors']}"
        end
      else
        Rails.logger.info "[Event Data Bus] #{iiitem['subj_id']} #{iiitem['relation_type_id']} #{iiitem['obj_id']} was not sent to Event Data Bus."
      end
    end
    push_items.length
  end
end
