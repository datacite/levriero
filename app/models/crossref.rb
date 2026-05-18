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
      "from-created-date" => options[:from_date],
      "until-created-date" => options[:until_date],
      mailto: "info@datacite.org",
      rows: options[:rows],
      page: options[:page],
    }.compact

    "#{ENV['CROSSREF_QUERY_URL']}/beta/datacitations?#{URI.encode_www_form(params)}"
  end

  def get_total(options = {})
    query_url = get_query_url(options.merge(rows: 0))
    result = Maremma.get(query_url, options)
    message = result.body.dig("data", "message").to_h
    message["total-results"].to_i
  end

  def queue_jobs(options = {})
    options[:offset] = options[:offset].to_i || 0
    options[:rows] = options[:rows].presence || job_batch_size
    options[:from_date] =
      options[:from_date].presence || (Time.now.to_date - 1.day).iso8601
    options[:until_date] =
      options[:until_date].presence || Time.now.to_date.iso8601
    options[:content_type] = "json"

    total = get_total(options)

    if total.positive?
      # walk through results paginated via page
      total_pages = (total.to_f / job_batch_size).ceil
      error_total = 0

      (0...total_pages).each do |page_num|
        options[:offset] = page_num * job_batch_size
        options[:total] = total
        options[:page] = page_num
        process_data(options)
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

    items = result.body.dig("data", "message", "items")
    # Rails.logger.info "Extracting related identifiers for #{items.size} DOIs updated from #{options[:from_date]} until #{options[:until_date]}."

    Array.wrap(items).map do |item|
      CrossrefImportJob.perform_later(item)
    end
  end

  def self.push_item(item)
    subj = cached_crossref_response(item["subject"]["id"])
    obj = cached_datacite_response(item["object"]["id"])

    data = {
      "data" => {
        "type" => "events",
        "attributes" => {
          "subjId" => item["subject"]["id"],
          "objId" => item["object"]["id"],
          "relationTypeId" => item["relation"].to_s.dasherize,
          "sourceId" => "crossref",
          "sourceToken" => ENV["CROSSREF_SOURCE_TOKEN"],
          "timestamp" => item["timestamp"],
          "subj" => subj,
          "obj" => obj,
        },
      },
    }

    send_event_import_message(data)

    Rails.logger.info "[Event Data] #{item["subject"]["id"]} #{item["relation"]} #{item["object"]["id"]} sent to the events queue."
  end
end
