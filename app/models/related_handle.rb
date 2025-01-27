class RelatedHandle < Base
  LICENSE = "https://creativecommons.org/publicdomain/zero/1.0/".freeze

  def self.import_by_month(options = {})
    from_date = (options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current).beginning_of_month
    until_date = (options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current).end_of_month

    # get first day of every month between from_date and until_date
    (from_date..until_date).select { |d| d.day == 1 }.each do |m|
      RelatedHandleImportByMonthJob.perform_later(from_date: m.strftime("%F"),
                                                  until_date: m.end_of_month.strftime("%F"))
    end

    "Queued import for DOIs updated from #{from_date.strftime('%F')} until #{until_date.strftime('%F')}."
  end

  def self.import(options = {})
    from_date = options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current - 1.day
    until_date = options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current

    related_handle = RelatedHandle.new
    related_handle.queue_jobs(related_handle.unfreeze(
                                from_date: from_date.strftime("%F"), until_date: until_date.strftime("%F"),
                              ))
  end

  def source_id
    "datacite_handle"
  end

  def query
    "relatedIdentifiers.relatedIdentifierType:Handle"
  end

  def push_data(result, _options = {})
    return result.body.fetch("errors") if result.body.fetch("errors",
                                                            nil).present?

    items = result.body.fetch("data", [])

    Array.wrap(items).map do |item|
      RelatedHandleImportJob.perform_later(item)
    rescue Aws::SQS::Errors::InvalidParameterValue,
           Aws::SQS::Errors::RequestEntityTooLarge, Seahorse::Client::NetworkingError => e
      logger = Logger.new($stdout)
      logger.error e.message
    end

    items.length
  end

  def self.push_item(item)
    attributes = item.fetch("attributes", {})
    doi = attributes.fetch("doi", nil)
    return nil if doi.blank?

    pid = normalize_doi(doi)
    related_handles = Array.wrap(attributes.fetch("relatedIdentifiers",
                                                  nil)).select do |r|
      r["relatedIdentifierType"] == "Handle"
    end
    push_items = Array.wrap(related_handles).reduce([]) do |ssum, iitem|
      related_handle = iitem.fetch("relatedIdentifier", nil).to_s.strip.downcase
      obj_id = normalize_handle(related_handle)
      source_id = "datacite_handle"
      source_token = ENV["DATACITE_HANDLE_SOURCE_TOKEN"]

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

    # there can be one or more related_handle per DOI
    Array.wrap(push_items).each do |iiitem|
      # send to DataCite Event Data Query API
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
end
