class OrcidClaim < Base
  include Queueable

  LICENSE = "https://creativecommons.org/publicdomain/zero/1.0/".freeze

  def self.import_by_month(options = {})
    from_date = (options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current).beginning_of_month
    until_date = (options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current).end_of_month

    # get first day of every month between from_date and until_date
    (from_date..until_date).select { |d| d.day == 1 }.each do |m|
      OrcidClaimImportByMonthJob.perform_later(from_date: m.strftime("%F"),
                                               until_date: m.end_of_month.strftime("%F"))
    end

    "Queued import for claims created from #{from_date.strftime('%F')} until #{until_date.strftime('%F')}."
  end

  def self.import(options = {})
    from_date = options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current - 1.day
    until_date = options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current

    orcid_claim = OrcidClaim.new
    orcid_claim.queue_jobs(orcid_claim.unfreeze(
                             from_date: from_date.strftime("%F"), until_date: until_date.strftime("%F"),
                           ))
  end

  def source_id
    "datacite_orcid_search_link"
  end

  def push_data(result, _options = {})
    return result.body.fetch("errors") if result.body.fetch("errors",
                                                            nil).present?

    items = result.body.dig("data", "response", "docs")

    Array.wrap(items).map do |item|
      NameIdentifierImportJob.perform_later(item)
    rescue Aws::SQS::Errors::InvalidParameterValue,
           Aws::SQS::Errors::RequestEntityTooLarge, Seahorse::Client::NetworkingError => e
      Rails.logger.error e.message
    end

    items.length
  end

  def self.push_item(item)
    doi = item.fetch("doi")
    pid = normalize_doi(doi)
    related_identifiers = item.fetch("relatedIdentifier", [])
    skip_doi = related_identifiers.any? do |related_identifier|
      ["IsIdenticalTo", "IsPartOf", "IsPreviousVersionOf",
       "IsVersionOf"].include?(related_identifier.split(":", 3).first)
    end
    name_identifiers = item.fetch("nameIdentifier", [])
    return nil if name_identifiers.blank? || skip_doi

    source_id = item.fetch("sourceId", "datacite_orcid_auto_update")
    relation_type_id = "is_authored_by"
    source_token = ENV["DATACITE_ORCID_AUTO_UPDATE_SOURCE_TOKEN"]

    push_items = Array.wrap(name_identifiers).reduce([]) do |ssum, iitem|
      name_identifier_scheme, name_identifier = iitem.split(":", 2)
      name_identifier = name_identifier.strip
      obj_id = normalize_orcid(name_identifier)

      if obj_id.present?
        subj = cached_datacite_response(pid)
        obj = cached_orcid_response(obj_id)

        ssum << { "message_action" => "create",
                  "subj_id" => pid,
                  "obj_id" => obj_id,
                  "relation_type_id" => relation_type_id,
                  "source_id" => source_id,
                  "source_token" => source_token,
                  "occurred_at" => item.fetch("updated"),
                  "timestamp" => Time.zone.now.iso8601,
                  "license" => LICENSE,
                  "subj" => subj,
                  "obj" => obj }
      end

      ssum
    end

    # there can be one or more name_identifier per DOI
    Array.wrap(push_items).each do |iiitem|
      # send to DataCite Event Datas API
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
  end
end
