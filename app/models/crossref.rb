class Crossref < Base
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
      "not-asserted-by" => "https://ror.org/04wxnsj81",
      "object.registration-agency" => "DataCite",
      "from-updated-time" => options[:from_date],
      "until-updated-time" => options[:until_date],
      "cursor" => options[:cursor],
      "rows" => options[:rows]
    }.compact

    "#{ENV['CROSSREF_QUERY_URL']}/relationships?#{URI.encode_www_form(params)}"
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
    return result.body.fetch("errors") if result.body.fetch("errors", nil).present?

    items = result.body.dig("data", "message", "relationships")

    Array.wrap(items).map do |item|
      CrossrefImportJob.perform_later(item)
    end

    [items.length, result.body.dig("data", "message", "next-cursor")]
  end

  def self.push_item(item)
    uuid = SecureRandom.uuid
    subj_id = item.fetch("subject", "id")
    obj_id = item.fetch("object", "id")

    subj = cached_crossref_response(subj_id)
    obj = cached_datacite_response(obj_id)

    return if ENV["STAFF_ADMIN_TOKEN"].blank?

    # so the id is important!!!
    # need to check this out
    push_url = ENV["LAGOTTINO_URL"] + "/events/#{uuid}"

    data = {
      "data" => {
        "id" => uuid,
        "type" => "events",
        "attributes" => {
          "messageAction" => "add",
          "subjId" => subj_id,
          "objId" => obj_id,
          "relationTypeId" => item["relationship_type"].to_s.dasherize,
          "sourceId" => "crossref",
          "sourceToken" => item["source_token"], # well this may very well be null now. it might be used to do a lookup on the crossref side.
          "occurredAt" => item["updated_time"],
          "timestamp" => Time.now.utc,
          "license" => "https://creativecommons.org/publicdomain/zero/1.0/",
          "subj" => subj,
          "obj" => obj,
        },
      },
    }

    response = Maremma.put(
      push_url,
      data: data.to_json,
      bearer: ENV["STAFF_ADMIN_TOKEN"],
      content_type: "application/vnd.api+json",
      accept: "application/vnd.api+json; version=2")

    if [200, 201].include?(response.status)
      Rails.logger.info "[Event Data] #{item['subj_id']} #{item['relation_type_id']} #{item['obj_id']} pushed to Event Data service."
    elsif response.status == 409
      Rails.logger.info "[Event Data] #{item['subj_id']} #{item['relation_type_id']} #{item['obj_id']} already pushed to Event Data service."
    elsif response.body["errors"].present?
      Rails.logger.error "[Event Data] #{item['subj_id']} #{item['relation_type_id']} #{item['obj_id']} had an error: #{response.body['errors']}"
      Rails.logger.error data.inspect
    end
  end
end
