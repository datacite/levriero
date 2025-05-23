class Crossref < Base
  include Queueable

  def self.import_by_month(options = {})
    from_date = (options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current).beginning_of_month
    until_date = (options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current).end_of_month

    # get first day of every month between from_date and until_date
    (from_date..until_date).select { |d| d.day == 1 }.each do |m|
      CrossrefImportByMonthJob.perform_later(from_date: m.strftime("%F"),
                                             until_date: m.end_of_month.strftime("%F"))
    end

    "Queued import for DOIs updated from #{from_date.strftime('%F')} until #{until_date.strftime('%F')}."
  end

  def self.import(options = {})
    from_date = options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current - 1.day
    until_date = options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current

    crossref = Crossref.new
    crossref.queue_jobs(crossref.unfreeze(from_date: from_date.strftime("%F"),
                                          until_date: until_date.strftime("%F"), host: true))
  end

  def source_id
    "crossref"
  end

  def get_query_url(options = {})
    params = {
      source: "crossref",
      "from-collected-date" => options[:from_date],
      "until-collected-date" => options[:until_date],
      mailto: "info@datacite.org",
      scholix: true,
      rows: options[:rows],
      cursor: options[:cursor],
    }.compact

    "#{ENV['CROSSREF_QUERY_URL']}/v1/events?#{URI.encode_www_form(params)}"
  end

  def get_total(options = {})
    query_url = get_query_url(options.merge(rows: 0))
    result = Maremma.get(query_url, options)
    message = result.body.dig("data", "message").to_h
    [message["total-results"].to_i, message["next-cursor"]]
  end

  def queue_jobs(options = {})
    options[:offset] = options[:offset].to_i || 0
    options[:rows] = options[:rows].presence || job_batch_size
    options[:from_date] =
      options[:from_date].presence || (Time.now.to_date - 1.day).iso8601
    options[:until_date] =
      options[:until_date].presence || Time.now.to_date.iso8601
    options[:content_type] = "json"

    total, cursor = get_total(options)

    if total.positive?
      # walk through results paginated via cursor
      total_pages = (total.to_f / job_batch_size).ceil
      error_total = 0

      (0...total_pages).each do |page|
        options[:offset] = page * job_batch_size
        options[:total] = total
        options[:cursor] = cursor
        count, cursor = process_data(options)
      end
      text = "Queued import for #{total} DOIs updated #{options[:from_date]} - #{options[:until_date]}."
    else
      text = "No DOIs updated #{options[:from_date]} - #{options[:until_date]}."
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

    items = result.body.dig("data", "message", "events")
    # Rails.logger.info "Extracting related identifiers for #{items.size} DOIs updated from #{options[:from_date]} until #{options[:until_date]}."

    Array.wrap(items).map do |item|
      CrossrefImportJob.perform_later(item)
    end

    [items.length, result.body.dig("data", "message", "next-cursor")]
  end

  def self.push_item(item)
    subj = cached_crossref_response(item["subj_id"])
    obj = cached_datacite_response(item["obj_id"])

    data = {
      "data" => {
        "id" => item["id"],
        "type" => "events",
        "attributes" => {
          "messageAction" => item["action"],
          "subjId" => item["subj_id"],
          "objId" => item["obj_id"],
          "relationTypeId" => item["relation_type_id"].to_s.dasherize,
          "sourceId" => item["source_id"].to_s.dasherize,
          "sourceToken" => item["source_token"],
          "occurredAt" => item["occurred_at"],
          "timestamp" => item["timestamp"],
          "license" => item["license"],
          "subj" => subj,
          "obj" => obj,
        },
      },
    }

    send_event_import_message(data)

    Rails.logger.info "[Event Data] #{item['subj_id']} #{item['relation_type_id']} #{item['obj_id']} sent to the events queue."
  end
end
