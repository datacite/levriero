class CrossrefRelated < Base
  LICENSE = "https://creativecommons.org/publicdomain/zero/1.0/".freeze

  def self.import_by_month(options = {})
    from_date = (options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current).beginning_of_month
    until_date = (options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current).end_of_month

    # get first day of every month between from_date and until_date
    (from_date..until_date).select { |d| d.day == 1 }.each do |m|
      CrossrefRelatedImportByMonthJob.perform_later(
        from_date: m.strftime("%F"), until_date: m.end_of_month.strftime("%F"),
      )
    end

    "Queued import for DOIs created from #{from_date.strftime('%F')} until #{until_date.strftime('%F')}."
  end

  def self.import(options = {})
    from_date = options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current - 1.day
    until_date = options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current

    crossref_related = CrossrefRelated.new
    crossref_related.queue_jobs(crossref_related.unfreeze(
                                  from_date: from_date.strftime("%F"), until_date: until_date.strftime("%F"), host: true,
                                ))
  end

  def source_id
    "crossref_related"
  end

  def get_query_url(options = {})
    params = {
      filter: "reference-visibility:open,has-references:true,from-created-date:#{options[:from_date]},until-created-date:#{options[:until_date]}",
      mailto: "info@datacite.org",
      rows: options[:rows],
      cursor: options[:cursor],
    }.compact

    "https://api.crossref.org/works?#{URI.encode_www_form(params)}"
  end

  def get_total(options = {})
    query_url = get_query_url(options.merge(rows: 0, cursor: "*"))
    result = Maremma.get(query_url, options)
    message = result.body.dig("data", "message").to_h
    message["total-results"].to_i
  end

  def queue_jobs(options = {})
    options[:rows] = options[:rows].presence || job_batch_size
    options[:from_date] =
      options[:from_date].presence || (Time.now.to_date - 1.day).iso8601
    options[:until_date] =
      options[:until_date].presence || Time.now.to_date.iso8601

    total = get_total(options)

    if total.positive?
      # walk through results paginated via cursor, unless test environment
      total_pages = Rails.env.test? ? 1 : (total.to_f / job_batch_size).ceil
      error_total = 0
      cursor = "*"

      (0...total_pages).each do |_page|
        options[:total] = total
        options[:cursor] = cursor
        count, cursor = process_data(options)
      end
      text = "Queued #{source_id} import for #{total} DOIs created #{options[:from_date]} - #{options[:until_date]}."
    else
      text = "No DOIs created #{options[:from_date]} - #{options[:until_date]}."
    end

    Rails.logger.info "[Event Data] #{text}"

    # send slack notification
    options[:level] = if total.zero?
                        "warning"
                      elsif error_total.positive?
                        "danger"
                      else
                        "good"
                      end
    options[:title] = "Report for #{source_id}"
    if options[:slack_webhook_url].present?
      send_notification_to_slack(text,
                                 options)
    end

    # return number of works queued
    total
  end

  def push_data(result, _options = {})
    return result.body.fetch("errors") if result.body.fetch("errors",
                                                            nil).present?

    items = result.body.dig("data", "message", "items")

    Array.wrap(items).map do |item|
      CrossrefRelatedImportJob.perform_later(item)
    rescue Aws::SQS::Errors::InvalidParameterValue,
           Aws::SQS::Errors::RequestEntityTooLarge, Seahorse::Client::NetworkingError => e
      Rails.logger.error e.message
    end

    [items.length, result.body.dig("data", "message", "next-cursor")]
  end

  def self.push_item(item)
    doi = item.fetch("DOI", nil)
    return nil if doi.blank?

    pid = normalize_doi(doi)
    related_doi_identifiers = Array.wrap(item.fetch("reference",
                                                    nil)).select do |r|
      r["DOI"].present?
    end
    registration_agencies = {}
    relation_type_id = "cites"

    push_items = Array.wrap(related_doi_identifiers).reduce([]) do |ssum, iitem|
      related_identifier = iitem.fetch("DOI", nil).to_s.strip.downcase
      obj_id = normalize_doi(related_identifier)
      prefix = validate_prefix(related_identifier)
      unless registration_agencies[prefix]
        registration_agencies[prefix] =
          cached_doi_ra(related_identifier)
      end

      if registration_agencies[prefix].nil?
        Rails.logger.error "No DOI registration agency for prefix #{prefix} found."
        source_id = "crossref_related"
        source_token = ENV["CROSSREF_RELATED_SOURCE_TOKEN"]
        obj = {}
      elsif registration_agencies[prefix] == "Crossref"
        source_id = "crossref_related"
        source_token = ENV["CROSSREF_RELATED_SOURCE_TOKEN"]
        obj = cached_crossref_response(obj_id)
      elsif registration_agencies[prefix] == "DataCite"
        source_id = "crossref_datacite"
        source_token = ENV["CROSSREF_DATACITE_SOURCE_TOKEN"]
        obj = cached_datacite_response(obj_id)
      elsif registration_agencies[prefix].present?
        source_id = "crossref_#{registration_agencies[prefix].downcase}"
        source_token = ENV["CROSSREF_OTHER_SOURCE_TOKEN"]
        obj = {}
      end

      if registration_agencies[prefix].present? && obj_id.present?
        subj = cached_datacite_response(pid)

        ssum << { "message_action" => "create",
                  "id" => SecureRandom.uuid,
                  "subj_id" => pid,
                  "obj_id" => obj_id,
                  "relation_type_id" => relation_type_id,
                  "source_id" => source_id,
                  "source_token" => source_token,
                  "occurred_at" => item.dig("created", "date-time"),
                  "timestamp" => Time.zone.now.iso8601,
                  "license" => LICENSE,
                  "subj" => subj,
                  "obj" => obj }
      end

      ssum
    end

    # there can be one or more references per DOI
    # send to DataCite Event Data Query API
    # don't send to Event Data Bus
    Array.wrap(push_items).each do |iiitem|
      if ENV["STAFF_ADMIN_TOKEN"].present?
        push_url = "#{ENV['LAGOTTINO_URL']}/events"

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
end
