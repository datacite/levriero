require 'yajl'
require 'digest'

class UsageUpdate < Base
  LICENSE = "https://creativecommons.org/publicdomain/zero/1.0/"
  LOGGER = Logger.new(STDOUT)

  USAGE_RELATIONS = [
    "total-dataset-investigations-regular",
    "total-dataset-investigations-machine",
    "total-dataset-requests-machine",
    "total-dataset-requests-regular",
    "unique-dataset-investigations-regular",
    "unique-dataset-investigations-machine",
    "unique-dataset-requests-machine",
    "unique-dataset-requests-regular"
  ]

  RESOLUTION_RELATIONS = [
    "total-resolutions-regular",
    "total-resolutions-machine",
    "unique-resolutions-machine",
    "unique-resolutions-regular"
  ]

  def self.import(_options={})
    usage_update = UsageUpdate.new
    usage_update.queue_jobs 
  end

  def self.redirect response, options={}
    report = Report.new(response, options)
    text = "[Usage Report] Started to parse #{report.report_url}."
    LOGGER.info text
    # args = {header: report.header, url: report.report_url}
    case report.get_type
      when "normal" then Report.parse_normal_report(report)
      when "compressed" then Report.parse_multi_subset_report(report)
    end
  end

  def self.get_data report_url, _options={}
    return OpenStruct.new(body: { "errors" => "No Report given given"}) if report_url.blank?
    host = URI.parse(report_url).host.downcase
    report = Maremma.get(report_url, timeout: 120, host: host)
    report
  end

  def self.grab_record sqs_msg: nil, data: nil
    report_url = data.fetch("report_id", "")
    ReportImportJob.perform_later(report_url)
  end

  def sqs
    sqs = Aws::SQS::Client.new(region: ENV["AWS_REGION"])
    sqs
  end

  def self.format_event type, data, options={}
    fail "Not type given. Report #{data[:report_url]} not proccessed" if type.blank?
    fail "Report_id is missing" if data[:report_url].blank?

    if USAGE_RELATIONS.include?(type.downcase)
      source_id = "datacite-usage"
      source_token = ENV['DATACITE_USAGE_SOURCE_TOKEN']
    elsif RESOLUTION_RELATIONS.include?(type.downcase)
      source_id = "datacite-resolution"
      source_token = ENV['DATACITE_RESOLUTION_SOURCE_TOKEN']
    end
    { "message-action" => "create",
      "subj-id" => data[:report_url],
      "subj"=> {
        "id"=> data[:report_url],
        "issued"=> data[:created]
      },
      "total"=> data[:count],
      "obj-id" => data[:id],
      "relation-type-id" => type,
      "source-id" => source_id,
      "source-token" => source_token,
      "occurred-at" => data[:created_at],
      "license" => LICENSE 
    }
  end

  def self.push_datasets items, options={}
    if items.empty?
      LOGGER.info  "No works found in the Queue."
    else
      Array.wrap(items).map do |item|
        UsageUpdateExportJob.perform_later(item.to_json, options)
      end
    end
  end

  def self.push_item item, options={}
    item = JSON.parse(item)

    if item["subj-id"].blank?
      return LOGGER.info OpenStruct.new(body: { "errors" => [{ "title" => "There is no Subject" }] })
    elsif ENV['LAGOTTINO_TOKEN'].blank?
      return LOGGER.info OpenStruct.new(body: { "errors" => [{ "title" => "Access token missing." }] })
    elsif item["errors"].present?
      return LOGGER.info OpenStruct.new(body: { "errors" => [{ "title" => "#{item["errors"]["title"]}" }] }) 
    end

    data = wrap_event item, options
    push_url = ENV['LAGOTTINO_URL']  + "/events"

  
    response = Maremma.post(push_url, data: data.to_json,
                                      bearer: ENV['LAGOTTINO_TOKEN'],
                                      content_type: 'application/vnd.api+json',
                                      accept: 'application/vnd.api+json; version=2')
  end

  def self.wrap_event item, options={}
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
          "obj" => obj } }}
  end
end
