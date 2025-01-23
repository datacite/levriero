require "digest"

class UsageUpdate < Base
  include Queueable

  LICENSE = "https://creativecommons.org/publicdomain/zero/1.0/".freeze

  USAGE_RELATIONS = [
    "total-dataset-investigations-regular",
    "total-dataset-investigations-machine",
    "total-dataset-requests-machine",
    "total-dataset-requests-regular",
    "unique-dataset-investigations-regular",
    "unique-dataset-investigations-machine",
    "unique-dataset-requests-machine",
    "unique-dataset-requests-regular",
  ].freeze

  RESOLUTION_RELATIONS = [
    "total-resolutions-regular",
    "total-resolutions-machine",
    "unique-resolutions-machine",
    "unique-resolutions-regular",
  ].freeze

  def self.import(_options = {})
    usage_update = UsageUpdate.new
    usage_update.queue_jobs
  end

  def self.import_by_year(options = {})
    from_date = (options[:from_date].present? ? Date.parse(options[:from_date]) : Date.current).year
    until_date = (options[:until_date].present? ? Date.parse(options[:until_date]) : Date.current).year

    # get first day of every month between from_date and until_date
    (from_date..until_date).each do |year|
      meta = Maremma.get(get_query_url("year" => year, size: 25))
      total_pages = meta.body.dig("data", "meta", "total-pages")
      (1..total_pages).each do |m|
        UsageUpdateImportByYearJob.perform_later(number: m)
      end
    end

    "Queued import for usage reported from #{from_date} until #{until_date}."
  end

  def self.redirect(response, options = {})
    report = Report.new(response, options)
    text = "[Usage Report] Started to parse #{report.report_url}."
    Rails.logger.info text
    # args = {header: report.header, url: report.report_url}
    case report.get_type
    when "normal" then Report.parse_normal_report(report)
    when "compressed" then Report.parse_multi_subset_report(report)
    end
  end

  def self.get_data(report_url, _options = {})
    return OpenStruct.new(body: { "errors" => "No Report given given" }) if report_url.blank?

    host = URI.parse(report_url).host.downcase
    Maremma.get(report_url, timeout: 120, host: host)
  end

  def self.import_reports(options = {})
    reports = Maremma.get(get_query_url(options))
    reports.body["data"].fetch("reports", []).each do |report|
      ReportImportJob.perform_later("#{url}/#{report.fetch('id', nil)}")
    end
  end

  def self.get_query_url(options = {})
    options[:number] ||= 1
    options[:size] ||= 25
    options[:year] ||= Date.current.year

    params = {
      "page[number]" => options[:number],
      "page[size]" => options[:size],
      "year" => options[:year],
    }
    "#{url}?#{URI.encode_www_form(params)}"
  end

  def self.url
    "#{ENV['SASHIMI_QUERY_URL']}/reports"
  end

  def self.grab_record(sqs_msg: nil, data: nil)
    report_url = data.fetch("report_id", "")
    ReportImportJob.perform_later(report_url)
  end

  def sqs
    Aws::SQS::Client.new(region: ENV["AWS_REGION"])
  end

  def self.format_event(type, data, _options = {})
    # TODO: error class for fail and proper error handling
    fail "Not type given. Report #{data[:report_url]} not proccessed" if type.blank?
    fail "Report_id is missing" if data[:report_url].blank?

    if USAGE_RELATIONS.include?(type.downcase)
      source_id = "datacite-usage"
      source_token = ENV["DATACITE_USAGE_SOURCE_TOKEN"]
    elsif RESOLUTION_RELATIONS.include?(type.downcase)
      source_id = "datacite-resolution"
      source_token = ENV["DATACITE_RESOLUTION_SOURCE_TOKEN"]
    end

    { "message-action" => "create",
      "subj-id" => data[:report_url],
      "subj" => {
        "id" => data[:report_url],
        "issued" => data[:created],
      },
      "total" => data[:count],
      "obj-id" => data[:id],
      "relation-type-id" => type,
      "source-id" => source_id,
      "source-token" => source_token,
      "occurred-at" => data[:created_at],
      "license" => LICENSE }
  end

  def self.push_datasets(items, options = {})
    if items.empty?
      Rails.logger.warn "No works found in the Queue."
    else
      Array.wrap(items).map do |item|
        UsageUpdateExportJob.perform_later(item.to_json, options)
      end
    end
  end

  def self.push_item(item, options = {})
    item = JSON.parse(item)

    if item["subj-id"].blank?
      Rails.logger.error OpenStruct.new(body: { "errors" => [{ "title" => "There is no Subject" }] })
      return
    elsif ENV["STAFF_ADMIN_TOKEN"].blank?
      Rails.logger.error OpenStruct.new(body: { "errors" => [{ "title" => "Access token missing." }] })
      return
    elsif item["errors"].present?
      Rails.logger.error OpenStruct.new(body: { "errors" => [{ "title" => (item["errors"]["title"]).to_s }] })
      return
    end

    data = wrap_event item, options

    send_event_import_message(data)

    subj_id = data["data"]["attributes"]["subjId"]
    relation_type_id = data["data"]["attributes"]["relationTypeId"]
    obj_id = data["data"]["attributes"]["objId"]

    Rails.logger.info("[Event Data] #{subj_id} #{relation_type_id} #{obj_id} sent to the events queue.")
  end

  def self.wrap_event(item, options = {})
    obj = cached_datacite_response(item["obj-id"])
    subj = options[:report_meta]
    {
      "data" => {
        "type" => "events",
        "attributes" => {
          "messageAction" => item["message-action"],
          "subjId" => item["subj-id"],
          "total" => item["total"],
          "objId" => item["obj-id"],
          "relationTypeId" => item["relation-type-id"].to_s.dasherize,
          "sourceId" => item["source-id"].to_s.dasherize,
          "sourceToken" => item["source-token"],
          "occurredAt" => item["occurred-at"],
          "timestamp" => item["timestamp"],
          "license" => item["license"],
          "subj" => subj,
          "obj" => obj,
        },
      },
    }
  end
end
